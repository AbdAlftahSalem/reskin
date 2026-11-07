import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';

void main() {
  test('contrast ratio matches WCAG reference values', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
    // #767676 on white is the classic 4.54:1 AA boundary.
    expect(contrastRatio(const Color(0xFF767676), Colors.white),
        closeTo(4.54, 0.02));
  });

  test('ensureReadable fixes failing pairs and reports them', () {
    final bad = ColorScheme.fromSeed(seedColor: Colors.amber).copyWith(
      primary: const Color(0xFFFFD54F),
      onPrimary: const Color(0xFFFFF59D), // yellow on yellow
      surface: Colors.white,
      onSurface: const Color(0xFFEEEEEE), // grey on white
    );
    final (fixed, report) = ensureReadable(bad);
    expect(report.passesAA, isTrue);
    expect(report.adjustedCount, greaterThanOrEqualTo(2));
    expect(contrastRatio(fixed.onPrimary, fixed.primary),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(fixed.onSurface, fixed.surface),
        greaterThanOrEqualTo(4.5));
    expect(
        report.checks.firstWhere((c) => c.pair == 'onPrimary/primary').adjusted,
        isTrue);
  });

  test('a good scheme is left alone', () {
    final good = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final (fixed, report) = ensureReadable(good);
    expect(report.adjustedCount, 0);
    expect(fixed.onSurface, good.onSurface);
  });
}
