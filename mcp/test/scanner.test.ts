import { strict as assert } from 'node:assert';
import { test } from 'node:test';

import { applyFindings, maskDart, scanDartSource, suggestRole } from '../src/scanner.js';

const SRC = `
import 'package:flutter/material.dart';

class Card1 extends StatelessWidget {
  const Card1({super.key});
  // Colors.red in a comment is ignored
  @override
  Widget build(BuildContext context) {
    final label = 'Colors.blue in a string is ignored';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: const Text('hi', style: TextStyle(color: Colors.black87)),
    );
  }
}

final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
final ok = Colors.transparent;
`;

test('masks comments and strings without moving columns', () => {
  const m = maskDart(SRC);
  assert.equal(m.length, SRC.length);
  assert.ok(!m.includes('Colors.red'));
  assert.ok(!m.includes('Colors.blue'));
  assert.ok(m.includes('Colors.white'));
});

test('finds hardcoded colors with exact positions and context', () => {
  const f = scanDartSource(SRC, 'lib/card1.dart');
  assert.deepEqual(f.map((x) => x.match), ['Colors.white', 'Color(0x1F000000)', 'Colors.black87']);
  const white = f[0];
  assert.equal(white.line, 12);
  assert.equal(SRC.split('\n')[11].slice(white.column - 1, white.column - 1 + 12), 'Colors.white');
  assert.equal(white.property, 'color');
  assert.deepEqual(white.enclosing.slice(0, 2), ['BoxDecoration', 'Container']);
  assert.equal(white.kind, 'background');
  assert.equal(white.suggestion, 'Theme.of(context).colorScheme.surfaceContainerLowest');

  const border = f[1];
  assert.equal(border.kind, 'border');
  assert.equal(border.role, 'outlineVariant');
  assert.equal(border.removeConstAt.length, 1); // `const Color(`

  const text = f[2];
  assert.equal(text.kind, 'foreground');
  assert.equal(text.role, 'onSurface');
  assert.equal(text.suggestion, 'Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)');
  assert.equal(text.removeConstAt.length, 1); // the `const Text(`
  assert.equal(text.argb, '#DD000000');
});

test('theme definitions are skipped unless asked', () => {
  assert.equal(scanDartSource(SRC, 'lib/card1.dart').some((x) => x.match.includes('6750A4')), false);
  assert.equal(scanDartSource(SRC, 'lib/card1.dart', { includeThemeFiles: true }).some((x) => x.match.includes('6750A4')), true);
  assert.equal(scanDartSource('final c = Colors.red;', 'lib/app_theme.dart').length, 0);
});

test('applyFindings rewrites matches and drops invalid const', () => {
  const f = scanDartSource(SRC, 'lib/card1.dart');
  const out = applyFindings(SRC, f);
  assert.ok(!out.includes('Colors.white'));
  assert.ok(out.includes("child: Text('hi', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)))"));
  assert.ok(out.includes('Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.12))'));
  assert.equal(scanDartSource(out, 'lib/card1.dart').length, 0);
  assert.ok(out.includes('const Card1({super.key});')); // unrelated const untouched
});

test('fromARGB / fromRGBO and shades', () => {
  const f = scanDartSource(`Widget b(BuildContext context) => Icon(Icons.add, color: Color.fromRGBO(255, 0, 0, 1));
Widget c(BuildContext context) => Container(color: Colors.blue.shade700);
Widget d(BuildContext context) => Container(color: Color.fromARGB(255, 33, 150, 243));`, 'lib/x.dart');
  assert.equal(f.length, 3);
  assert.equal(f[0].argb, '#FFFF0000');
  assert.equal(f[0].role, 'error');
  assert.equal(f[1].match, 'Colors.blue.shade700');
  assert.equal(f[2].role, 'primary');
});

test('role heuristics', () => {
  assert.equal(suggestRole('color', ['TextStyle'], 0xFF9E9E9E).role, 'onSurfaceVariant');
  assert.equal(suggestRole('color', ['TextStyle'], 0xFFFFFFFF).role, 'onPrimary');
  assert.equal(suggestRole('color', ['Container'], 0xFFF2F3F5).role, 'surfaceContainerHighest');
  assert.equal(suggestRole('shadowColor', ['Card'], 0xFF000000).role, 'shadow');
});

test('colors inside a TextStyle copyWith are foreground colors', () => {
  const src = `
Widget build(BuildContext context) {
  final text = Theme.of(context).textTheme;
  return Column(children: [
    Text('a', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
    Text('b', style: widget.style.copyWith(color: const Color(0xFF8A4B2A))),
    Container(decoration: box.copyWith(color: const Color(0xFFFFF1D6))),
  ]);
}
`;
  const f = scanDartSource(src, 'lib/a.dart');
  assert.equal(f.length, 3);
  assert.equal(f[0].kind, 'foreground');
  assert.equal(f[0].role, 'onPrimary');
  assert.equal(f[1].kind, 'foreground');
  assert.equal(f[1].role, 'primary');
  assert.equal(f[2].kind, 'background');
});
