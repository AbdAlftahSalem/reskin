import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';

void main() {
  const provider = OfflineThemeProvider();

  test('parses "X on Y" as accent on background', () {
    final i = parsePrompt('Ramadan night, gold on navy');
    expect(i.accent, kColorWords['gold']);
    expect(i.background, kColorWords['navy']);
    expect(i.seed, kColorWords['navy']);
    expect(i.matched, containsAll(<String>['ramadan', 'gold on navy']));
    expect(i.headingFont, 'El Messiri');
    expect(i.title, 'Ramadan Night');
  });

  test('short X-on-Y prompts get a readable title', () {
    expect(parsePrompt('gold on navy').title, 'Gold on Navy');
  });

  test('mood words set fonts and radius', () {
    final i = parsePrompt('minimal fintech');
    expect(i.headingFont, 'Inter');
    expect(i.radius, 4);
    expect(parsePrompt('playful, very round').radius, 24);
  });

  test('unknown prompts still give a stable seed', () {
    final a = parsePrompt('zzz qqq');
    final b = parsePrompt('zzz qqq');
    expect(a.seed, b.seed);
    expect(parsePrompt('zzz qqq').seed, isNot(parsePrompt('www').seed));
  });

  test('offline provider is deterministic and gives N readable variants',
      () async {
    final a = await provider.generate(const ReskinPrompt.text('ocean sunset'));
    final b = await provider.generate(const ReskinPrompt.text('ocean sunset'));
    expect(a, hasLength(4));
    expect(a.map((t) => t.name).toSet(), hasLength(4));
    for (var k = 0; k < a.length; k++) {
      expect(a[k].light, b[k].light);
      expect(a[k].dark, b[k].dark);
      expect(ensureReadable(a[k].light).$2.adjustedCount, 0, reason: a[k].name);
      expect(ensureReadable(a[k].dark).$2.adjustedCount, 0, reason: a[k].name);
    }
  });

  test('gold on navy: dark surfaces come from navy, accent is gold-ish',
      () async {
    final v = await provider.generate(const ReskinPrompt.text('gold on navy'));
    final dark = v.first.dark;
    final surface = HSLColor.fromColor(dark.surface);
    expect(surface.hue, inInclusiveRange(200, 240)); // navy family
    expect(surface.lightness, lessThan(0.2));
    final secondary = HSLColor.fromColor(dark.secondary);
    expect(secondary.hue, inInclusiveRange(30, 60)); // gold family
  });

  test('seed prompts use the seed', () async {
    final v = await provider
        .generate(const ReskinPrompt.seed(Color(0xFF00897B), count: 2));
    expect(v, hasLength(2));
    expect(v.first.source, 'seed');
  });

  test('toThemeData applies fonts and radius', () {
    final t = ReskinTheme.fromSeed(Colors.teal,
        headingFont: 'Manrope', bodyFont: 'Inter', radius: 20);
    final d = t.toThemeData(Brightness.dark);
    expect(d.brightness, Brightness.dark);
    expect(d.textTheme.headlineSmall?.fontFamily, 'Manrope');
    expect(d.textTheme.bodyMedium?.fontFamily, 'Inter');
    final shape = d.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(20));
  });
}
