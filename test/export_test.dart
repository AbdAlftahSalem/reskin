import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';

void main() {
  test('export writes every scheme role for light and dark', () async {
    final t = (await const OfflineThemeProvider()
            .generate(const ReskinPrompt.text('gold on navy')))
        .first;
    final code = exportThemeDart(t);
    expect(code, contains('class AppTheme'));
    expect(code, contains("import 'package:flutter/material.dart';"));
    expect(code, contains('brightness: Brightness.light'));
    expect(code, contains('brightness: Brightness.dark'));
    for (final (role, _) in schemeRoles(t.light)) {
      expect(RegExp('\\b$role: Color\\(0x').allMatches(code).length, 2,
          reason: role);
    }
    final hex = t.dark.surface
        .toARGB32()
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    expect(code, contains('surface: Color(0x$hex)'));
    expect(
        code,
        contains(
            'static const double radius = ${t.radius.toStringAsFixed(1)};'));
    expect(code, contains('prompt: "gold on navy"'));
    expect(exportThemeDart(t.copyWith(headingFont: 'El Messiri')),
        contains("static const String headingFont = 'El Messiri';"));
    expect(code, contains('static const String? headingFont = null;'));
  });

  test('custom class name and null fonts', () {
    final code = exportThemeDart(ReskinTheme.fromSeed(Colors.teal),
        className: 'BrandTheme');
    expect(code, contains('class BrandTheme'));
    expect(code, contains('BrandTheme._();'));
    expect(code, contains('static const String? headingFont = null;'));
  });
}
