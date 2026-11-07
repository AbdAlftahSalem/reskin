import { readdir, readFile, stat } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';

/** One hardcoded color found in Dart source. */
export interface ColorFinding {
  file: string;        // relative to the project root, forward slashes
  line: number;        // 1-based
  column: number;      // 1-based
  match: string;       // exact source text, e.g. `Colors.white` or `Color(0xFF2F80ED)`
  argb: string | null; // resolved #AARRGGBB when known
  property: string | null;  // e.g. `color`, `backgroundColor`
  enclosing: string[];      // innermost first, e.g. ['BoxDecoration', 'Container']
  kind: 'foreground' | 'background' | 'border' | 'shadow';
  suggestion: string;       // replacement expression
  role: string;             // ColorScheme role in the suggestion
  removeConstAt: { line: number; column: number }[]; // `const` keywords that must go
  confidence: 'high' | 'medium' | 'low';
}

export interface ScanOptions {
  /** Also report colors inside theme definitions (files named *theme*, seedColor:, ColorScheme(...)). */
  includeThemeFiles?: boolean;
  /** Sub-directory to scan, default `lib`. */
  dir?: string;
}

const MATERIAL: Record<string, number> = {
  white: 0xFFFFFFFF, black: 0xFF000000, black87: 0xDD000000, black54: 0x8A000000,
  black45: 0x73000000, black38: 0x61000000, black26: 0x42000000, black12: 0x1F000000,
  white70: 0xB3FFFFFF, white54: 0x8AFFFFFF, white38: 0x62FFFFFF, white24: 0x3DFFFFFF, white12: 0x1FFFFFFF,
  red: 0xFFF44336, pink: 0xFFE91E63, purple: 0xFF9C27B0, deepPurple: 0xFF673AB7, indigo: 0xFF3F51B5,
  blue: 0xFF2196F3, lightBlue: 0xFF03A9F4, cyan: 0xFF00BCD4, teal: 0xFF009688, green: 0xFF4CAF50,
  lightGreen: 0xFF8BC34A, lime: 0xFFCDDC39, yellow: 0xFFFFEB3B, amber: 0xFFFFC107, orange: 0xFFFF9800,
  deepOrange: 0xFFFF5722, brown: 0xFF795548, grey: 0xFF9E9E9E, blueGrey: 0xFF607D8B,
  redAccent: 0xFFFF5252, pinkAccent: 0xFFFF4081, blueAccent: 0xFF448AFF, greenAccent: 0xFF69F0AE,
};

const COLOR_RE =
  /\bColor\(\s*0x([0-9A-Fa-f]{6,8})\s*\)|\bColor\.from(?:ARGB|RGBO)\(([^)]*)\)|\bColors\.(?!transparent\b)([a-zA-Z]+[0-9]*)(?:\[(\d+)\]|\.shade(\d+))?/g;

/** Replace string literal contents and comments with spaces, keeping columns. */
export function maskDart(src: string): string {
  const out = src.split('');
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    const next = src[i + 1];
    if (c === '/' && next === '/') {
      while (i < n && src[i] !== '\n') { out[i] = ' '; i++; }
      continue;
    }
    if (c === '/' && next === '*') {
      while (i < n && !(src[i] === '*' && src[i + 1] === '/')) { if (src[i] !== '\n') out[i] = ' '; i++; }
      if (i < n) { out[i] = ' '; out[i + 1] = ' '; i += 2; }
      continue;
    }
    if (c === "'" || c === '"') {
      const triple = src.substr(i, 3) === c.repeat(3);
      const q = triple ? c.repeat(3) : c;
      const raw = i > 0 && src[i - 1] === 'r';
      i += q.length;
      while (i < n && src.substr(i, q.length) !== q) {
        if (!raw && src[i] === '\\') { out[i] = ' '; if (src[i + 1] !== '\n') out[i + 1] = ' '; i += 2; continue; }
        if (!triple && src[i] === '\n') break;
        if (src[i] !== '\n') out[i] = ' ';
        i++;
      }
      i += q.length;
      continue;
    }
    i++;
  }
  return out.join('');
}

function argbOf(m: RegExpExecArray): number | null {
  if (m[1]) {
    const h = m[1].length === 6 ? 'FF' + m[1] : m[1];
    return parseInt(h, 16) >>> 0;
  }
  if (m[3]) {
    const base = MATERIAL[m[3]];
    if (base === undefined) return null;
    if (m[4] || m[5]) return null; // shades: value unknown here, still hardcoded
    return base >>> 0;
  }
  if (m[2]) {
    const nums = m[2].split(',').map((s) => parseFloat(s.trim()));
    if (nums.length === 4 && nums.every((x) => !Number.isNaN(x))) {
      const isRGBO = m[0].includes('RGBO');
      const [a0, b0, c0, d0] = nums;
      const a = isRGBO ? Math.round(d0 * 255) : a0;
      const r = isRGBO ? a0 : b0;
      const g = isRGBO ? b0 : c0;
      const b = isRGBO ? c0 : d0;
      return (((a & 255) << 24) | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255)) >>> 0;
    }
  }
  return null;
}

function hsl(argb: number): { h: number; s: number; l: number; a: number } {
  const a = ((argb >>> 24) & 255) / 255;
  const r = ((argb >>> 16) & 255) / 255;
  const g = ((argb >>> 8) & 255) / 255;
  const b = (argb & 255) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
  }
  return { h, s, l, a };
}

const FG_WIDGETS = new Set(['TextStyle', 'Text', 'Icon', 'IconThemeData', 'ImageIcon', 'TextSpan', 'IconButton']);
const FG_PROPS = new Set(['foregroundColor', 'textColor', 'iconColor', 'labelColor', 'selectedItemColor', 'unselectedItemColor']);

/** Picks a ColorScheme role for a hardcoded color, from where it is used and what it looks like. */
export function suggestRole(property: string | null, enclosing: string[], argb: number | null):
  { role: string; kind: ColorFinding['kind']; confidence: ColorFinding['confidence'] } {
  const inner = enclosing[0] ?? '';
  const prop = property ?? '';
  if (/shadow/i.test(prop) || inner === 'BoxShadow' || inner === 'Shadow') return { role: 'shadow', kind: 'shadow', confidence: 'high' };
  if (/border|divider|outline/i.test(prop) || ['Border', 'BorderSide', 'Divider', 'VerticalDivider'].includes(inner) || inner.startsWith('Border.')) {
    return { role: 'outlineVariant', kind: 'border', confidence: 'medium' };
  }
  const fg = FG_WIDGETS.has(inner) || FG_PROPS.has(prop) || (inner === 'TextStyle');
  const c = argb === null ? null : hsl(argb);
  if (fg) {
    if (!c) return { role: 'onSurface', kind: 'foreground', confidence: 'low' };
    if (c.s > 0.35 && c.l > 0.15 && c.l < 0.85) {
      if (c.h < 20 || c.h > 340) return { role: 'error', kind: 'foreground', confidence: 'medium' };
      return { role: 'primary', kind: 'foreground', confidence: 'medium' };
    }
    if (c.l >= 0.85) return { role: 'onPrimary', kind: 'foreground', confidence: 'medium' };
    if (c.l <= 0.3) return { role: 'onSurface', kind: 'foreground', confidence: 'high' };
    return { role: 'onSurfaceVariant', kind: 'foreground', confidence: 'high' };
  }
  if (!c) return { role: 'surfaceContainerHighest', kind: 'background', confidence: 'low' };
  if (c.s > 0.35 && c.l > 0.15 && c.l < 0.85) {
    if (c.h < 20 || c.h > 340) return { role: 'error', kind: 'background', confidence: 'medium' };
    return { role: 'primary', kind: 'background', confidence: 'medium' };
  }
  if (c.l >= 0.99) return { role: 'surfaceContainerLowest', kind: 'background', confidence: 'medium' };
  if (c.l >= 0.85) return { role: 'surfaceContainerHighest', kind: 'background', confidence: 'medium' };
  if (c.l <= 0.2) return { role: 'inverseSurface', kind: 'background', confidence: 'low' };
  return { role: 'surfaceContainerHigh', kind: 'background', confidence: 'low' };
}

interface Opener { name: string; index: number; constAt: number | null }

/** Unclosed constructor calls before `pos`, innermost first. */
function openers(masked: string, pos: number, limit = 4000): Opener[] {
  const out: Opener[] = [];
  let depth = 0;
  const start = Math.max(0, pos - limit);
  for (let i = pos - 1; i >= start; i--) {
    const ch = masked[i];
    if (ch === ')' || ch === ']' || ch === '}') depth++;
    else if (ch === '(' || ch === '[' || ch === '{') {
      if (depth > 0) { depth--; continue; }
      if (ch === '{') {
        // A block or function body ends the expression: stop at the statement boundary.
        const before = masked.slice(Math.max(0, i - 3), i);
        if (!/=>\s*$/.test(before)) break;
        continue;
      }
      if (ch !== '(') continue;
      const m = /([A-Za-z_][\w.]*)\s*(?:<[^<>()]*>)?\s*$/.exec(masked.slice(Math.max(0, i - 80), i));
      const name = m ? m[1] : '';
      let constAt: number | null = null;
      if (m) {
        const nameStart = i - m[0].length;
        const pre = masked.slice(Math.max(0, nameStart - 10), nameStart);
        const cm = /\bconst\s+$/.exec(pre);
        if (cm) constAt = nameStart - cm[0].length;
      }
      out.push({ name, index: i, constAt });
    } else if (ch === ';' && depth === 0) {
      break;
    }
  }
  return out;
}

function lineCol(lineStarts: number[], index: number): { line: number; column: number } {
  let lo = 0;
  let hi = lineStarts.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (lineStarts[mid] <= index) lo = mid; else hi = mid - 1;
  }
  return { line: lo + 1, column: index - lineStarts[lo] + 1 };
}

/** Scan one Dart file's source. */
export function scanDartSource(src: string, file: string, opts: ScanOptions = {}): ColorFinding[] {
  const masked = maskDart(src);
  const lineStarts = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === '\n') lineStarts.push(i + 1);
  const themeFile = /theme/i.test(file.split('/').pop() ?? '');
  if (themeFile && !opts.includeThemeFiles) return [];
  const out: ColorFinding[] = [];
  COLOR_RE.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = COLOR_RE.exec(masked)) !== null) {
    const index = m.index;
    const text = src.slice(index, index + m[0].length);
    const ops = openers(masked, index);
    const names = ops.map((o) => o.name).filter((n) => n.length > 0);
    if (!opts.includeThemeFiles && names.some((n) => /^(ColorScheme|ThemeData)/.test(n))) continue;
    const before = masked.slice(Math.max(0, index - 120), index);
    const pm = /([A-Za-z_]\w*)\s*:\s*(?:const\s+)?$/.exec(before);
    const property = pm ? pm[1] : null;
    if (property === 'seedColor' && !opts.includeThemeFiles) continue;
    const argb = argbOf(m);
    const { role, kind, confidence } = suggestRole(property, names, argb);
    let alpha = '';
    if (argb !== null) {
      const a = (argb >>> 24) & 255;
      if (a < 255) alpha = `.withValues(alpha: ${(a / 255).toFixed(2)})`;
    }
    const removeConstAt = ops
      .filter((o) => o.constAt !== null)
      .map((o) => lineCol(lineStarts, o.constAt as number));
    // `const Color(...)` itself.
    const selfConst = /\bconst\s+$/.exec(masked.slice(Math.max(0, index - 10), index));
    if (selfConst) removeConstAt.unshift(lineCol(lineStarts, index - selfConst[0].length));
    const lc = lineCol(lineStarts, index);
    out.push({
      file,
      line: lc.line,
      column: lc.column,
      match: text,
      argb: argb === null ? null : '#' + argb.toString(16).toUpperCase().padStart(8, '0'),
      property,
      enclosing: names.slice(0, 3),
      kind,
      role,
      suggestion: `Theme.of(context).colorScheme.${role}${alpha}`,
      removeConstAt,
      confidence,
    });
  }
  return out;
}

async function walk(dir: string, acc: string[]): Promise<string[]> {
  let entries;
  try { entries = await readdir(dir, { withFileTypes: true }); } catch { return acc; }
  for (const e of entries) {
    if (e.name.startsWith('.') || e.name === 'build') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) await walk(p, acc);
    else if (e.name.endsWith('.dart') && !/\.(g|freezed)\.dart$/.test(e.name)) acc.push(p);
  }
  return acc;
}

/** Scan `<root>/lib` (or opts.dir) for hardcoded colors. */
export async function scanProject(root: string, opts: ScanOptions = {}): Promise<ColorFinding[]> {
  const base = join(root, opts.dir ?? 'lib');
  const s = await stat(base).catch(() => null);
  if (!s || !s.isDirectory()) throw new Error(`No ${opts.dir ?? 'lib'}/ directory under ${root}`);
  const files = (await walk(base, [])).sort();
  const out: ColorFinding[] = [];
  for (const f of files) {
    const src = await readFile(f, 'utf8');
    out.push(...scanDartSource(src, relative(root, f).split(sep).join('/'), opts));
  }
  return out;
}

/**
 * Apply findings to a source string (what an agent would do): replace each match with its
 * suggestion and drop the `const` keywords that would no longer compile. Returns the new source.
 */
export function applyFindings(src: string, findings: ColorFinding[]): string {
  const lineStarts = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === '\n') lineStarts.push(i + 1);
  const idx = (l: number, c: number) => lineStarts[l - 1] + c - 1;
  type Edit = { at: number; len: number; text: string };
  const edits: Edit[] = [];
  const consts = new Set<number>();
  for (const f of findings) {
    edits.push({ at: idx(f.line, f.column), len: f.match.length, text: f.suggestion });
    for (const k of f.removeConstAt) consts.add(idx(k.line, k.column));
  }
  for (const at of consts) {
    const m = /^const\s+/.exec(src.slice(at));
    if (m) edits.push({ at, len: m[0].length, text: '' });
  }
  edits.sort((a, b) => b.at - a.at);
  let out = src;
  for (const e of edits) out = out.slice(0, e.at) + e.text + out.slice(e.at + e.len);
  return out;
}
