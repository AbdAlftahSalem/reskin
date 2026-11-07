#!/usr/bin/env node
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, resolve } from 'node:path';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

import { applyFindings, scanProject, type ColorFinding } from './scanner.js';
import { connectWebSocket, VmServiceClient } from './vm.js';

const VERSION = '0.1.0';

function projectRoot(p?: string): string {
  return resolve(p ?? process.env.RESKIN_PROJECT ?? process.cwd());
}

async function withVm<T>(uri: string | undefined, fn: (c: VmServiceClient) => Promise<T>): Promise<T> {
  const u = uri ?? process.env.RESKIN_VM_SERVICE_URI;
  if (!u) {
    throw new Error(
      'No VM service URI. Run the app with `flutter run` (debug) and pass the "Dart VM Service" ' +
      'URI it prints as vmServiceUri, or set RESKIN_VM_SERVICE_URI.');
  }
  const client = new VmServiceClient(await connectWebSocket(u));
  try { return await fn(client); } finally { client.close(); }
}

function text(obj: unknown) {
  return { content: [{ type: 'text' as const, text: typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2) }] };
}

function errorResult(e: unknown) {
  return { isError: true, content: [{ type: 'text' as const, text: String((e as Error)?.message ?? e) }] };
}

function summarize(findings: ColorFinding[]): string {
  if (findings.length === 0) return 'No hardcoded colors found. Everything comes from the theme.';
  const lines = findings.map((f) =>
    `${f.file}:${f.line}:${f.column}  ${f.match}  →  ${f.suggestion}` +
    (f.removeConstAt.length ? `   (remove const at ${f.removeConstAt.map((c) => `${c.line}:${c.column}`).join(', ')})` : ''));
  return `${findings.length} hardcoded color(s):\n` + lines.join('\n');
}

export function createServer(): McpServer {
  const server = new McpServer({ name: 'reskin-mcp', version: VERSION });

  server.registerTool('xray', {
    title: 'X-ray hardcoded colors',
    description:
      'Statically scans a Flutter project\'s lib/ for hardcoded colors (Color(0x…), Color.fromARGB/RGBO, Colors.x) ' +
      'and returns file:line:column, the exact source text, and a suggested Theme.of(context).colorScheme.<role> ' +
      'replacement plus any `const` keywords that must be removed. Theme definition files are skipped by default. ' +
      'With vmServiceUri it also returns the running app\'s runtime X-ray (what is on screen).',
    inputSchema: {
      projectPath: z.string().optional().describe('Flutter project root (default: RESKIN_PROJECT or cwd)'),
      includeThemeFiles: z.boolean().optional().describe('Also report colors in theme definitions'),
      vmServiceUri: z.string().optional().describe('Optional: running app VM service URI for the runtime X-ray'),
    },
  }, async ({ projectPath, includeThemeFiles, vmServiceUri }) => {
    try {
      const root = projectRoot(projectPath);
      const findings = await scanProject(root, { includeThemeFiles });
      let runtime: unknown;
      if (vmServiceUri) runtime = await withVm(vmServiceUri, (c) => c.reskin('xray'));
      return text({ summary: summarize(findings), root, findings, ...(runtime ? { runtime } : {}) });
    } catch (e) { return errorResult(e); }
  });

  server.registerTool('apply_theme', {
    title: 'Apply a theme to the running app',
    description:
      'Generates theme variants from a prompt ("gold on navy", "minimal fintech") and/or a seed color and applies ' +
      'the first (or `select`) to the running Flutter app through reskin\'s VM service extension. Needs the app in ' +
      'debug mode with Reskin.builder(). Uses whatever provider the app configured (offline by default).',
    inputSchema: {
      prompt: z.string().optional(),
      seed: z.string().regex(/^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/).optional().describe('#RRGGBB'),
      count: z.number().int().min(1).max(8).optional(),
      select: z.number().int().min(-1).optional().describe('Variant index to apply, -1 = original'),
      mode: z.enum(['light', 'dark', 'system']).optional(),
      vmServiceUri: z.string().optional(),
    },
  }, async ({ prompt, seed, count, select, mode, vmServiceUri }) => {
    try {
      if (!prompt && !seed) throw new Error('Give a prompt and/or a seed color.');
      const out = await withVm(vmServiceUri, async (c) => {
        const applied = await c.reskin('applyTheme', {
          prompt, seed, count: count?.toString(), select: select?.toString(),
        });
        if (mode) await c.reskin('setMode', { mode });
        return applied;
      });
      return text(out);
    } catch (e) { return errorResult(e); }
  });

  server.registerTool('export_theme', {
    title: 'Export app_theme.dart',
    description:
      'Gets the theme currently applied in the running app as a plain, dependency-free app_theme.dart ' +
      '(light + dark ColorScheme constants, fonts, radius). Optionally writes it into the project.',
    inputSchema: {
      vmServiceUri: z.string().optional(),
      writeTo: z.string().optional().describe('Path to write, relative to projectPath (e.g. lib/app_theme.dart)'),
      projectPath: z.string().optional(),
    },
  }, async ({ vmServiceUri, writeTo, projectPath }) => {
    try {
      const res = await withVm(vmServiceUri, (c) => c.reskin<{ name: string; code: string }>('exportTheme'));
      if (writeTo) {
        const root = projectRoot(projectPath);
        const target = isAbsolute(writeTo) ? writeTo : join(root, writeTo);
        if (!resolve(target).startsWith(root)) throw new Error('writeTo must stay inside the project.');
        await mkdir(dirname(target), { recursive: true });
        await writeFile(target, res.code, 'utf8');
        return text({ name: res.name, written: target, bytes: Buffer.byteLength(res.code) });
      }
      return text(res.code);
    } catch (e) { return errorResult(e); }
  });

  return server;
}

async function main(): Promise<void> {
  if (process.argv.includes('--version')) { console.log(VERSION); return; }
  if (process.argv[2] === 'scan') {
    // CLI convenience: reskin-mcp scan [projectPath] [--json]
    const root = projectRoot(process.argv[3] && !process.argv[3].startsWith('--') ? process.argv[3] : undefined);
    const findings = await scanProject(root);
    console.log(process.argv.includes('--json') ? JSON.stringify(findings, null, 2) : summarize(findings));
    return;
  }
  if (process.argv[2] === 'fix') {
    // CLI: reskin-mcp fix [projectPath] [--dry-run] — applies every suggestion (what an agent would do).
    const root = projectRoot(process.argv[3] && !process.argv[3].startsWith('--') ? process.argv[3] : undefined);
    const findings = await scanProject(root);
    const byFile = new Map<string, ColorFinding[]>();
    for (const f of findings) byFile.set(f.file, [...(byFile.get(f.file) ?? []), f]);
    for (const [file, list] of byFile) {
      const path = join(root, file);
      const src = await readFile(path, 'utf8');
      const out = applyFindings(src, list);
      if (!process.argv.includes('--dry-run')) await writeFile(path, out, 'utf8');
      console.log(`${process.argv.includes('--dry-run') ? 'would fix' : 'fixed'} ${list.length} in ${file}`);
    }
    if (findings.length === 0) console.log('Nothing to fix.');
    return;
  }
  const server = createServer();
  await server.connect(new StdioServerTransport());
}

const invokedDirectly = process.argv[1] && (await readFile(process.argv[1], 'utf8').then(() => true).catch(() => false))
  && import.meta.url.endsWith(process.argv[1].split('/').pop() ?? '');
if (invokedDirectly) {
  main().catch((e) => { console.error(e); process.exit(1); });
}
