import { strict as assert } from 'node:assert';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const server = fileURLToPath(new URL('../src/index.js', import.meta.url));

test('speaks MCP over stdio: lists 3 tools and runs xray', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'reskin-mcp-'));
  await mkdir(join(dir, 'lib'));
  await writeFile(join(dir, 'lib', 'a.dart'),
    "import 'package:flutter/material.dart';\nWidget a(BuildContext context) => Container(color: Colors.white);\n");

  const child = spawn(process.execPath, [server], { stdio: ['pipe', 'pipe', 'inherit'] });
  let buf = '';
  const waiters = new Map<number, (v: any) => void>();
  child.stdout.on('data', (d) => {
    buf += d.toString();
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i); buf = buf.slice(i + 1);
      if (!line.trim()) continue;
      const msg = JSON.parse(line);
      waiters.get(msg.id)?.(msg);
    }
  });
  let id = 0;
  const rpc = (method: string, params: unknown) => new Promise<any>((resolve, reject) => {
    const my = ++id;
    const t = setTimeout(() => reject(new Error('timeout ' + method)), 10000);
    waiters.set(my, (m) => { clearTimeout(t); resolve(m); });
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: my, method, params }) + '\n');
  });

  try {
    const init = await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } });
    assert.equal(init.result.serverInfo.name, 'reskin-mcp');
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');

    const list = await rpc('tools/list', {});
    assert.deepEqual(list.result.tools.map((t: { name: string }) => t.name).sort(), ['apply_theme', 'export_theme', 'xray']);

    const x = await rpc('tools/call', { name: 'xray', arguments: { projectPath: dir } });
    const body = JSON.parse(x.result.content[0].text);
    assert.equal(body.findings.length, 1);
    assert.equal(body.findings[0].file, 'lib/a.dart');
    assert.equal(body.findings[0].line, 2);
    assert.match(body.summary, /lib\/a\.dart:2:\d+ {2}Colors\.white {2}→ {2}Theme\.of\(context\)\.colorScheme\./);

    const noVm = await rpc('tools/call', { name: 'apply_theme', arguments: { prompt: 'gold on navy' } });
    assert.equal(noVm.result.isError, true);
    assert.match(noVm.result.content[0].text, /VM service URI/);
  } finally {
    child.kill();
  }
});
