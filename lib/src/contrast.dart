import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.x relative luminance of [c] (alpha ignored).
double relativeLuminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : _pow((v + 0.055) / 1.055, 2.4);
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _pow(double x, double e) => math.pow(x, e).toDouble();

/// WCAG contrast ratio between two opaque colors, from 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// One foreground/background pair checked by [ensureReadable].
@immutable
class ContrastCheck {
  const ContrastCheck({
    required this.pair,
    required this.ratio,
    required this.adjusted,
  });

  /// Like `onPrimary/primary`.
  final String pair;

  /// Ratio after any adjustment.
  final double ratio;

  /// Whether reskin replaced the foreground to reach AA.
  final bool adjusted;

  bool get passesAA => ratio >= 4.5;

  @override
  String toString() =>
      '$pair ${ratio.toStringAsFixed(2)}:1${adjusted ? ' (fixed)' : ''}';
}

/// Result of checking a [ColorScheme] against WCAG AA (4.5:1 for text).
@immutable
class ContrastReport {
  const ContrastReport(this.checks);
  final List<ContrastCheck> checks;
  bool get passesAA => checks.every((c) => c.passesAA);
  int get adjustedCount => checks.where((c) => c.adjusted).length;
  double get worstRatio =>
      checks.map((c) => c.ratio).fold(21, (a, b) => a < b ? a : b);
}

/// The text-on-background pairs reskin guarantees.
const List<String> kCheckedPairs = <String>[
  'onPrimary/primary',
  'onPrimaryContainer/primaryContainer',
  'onSecondary/secondary',
  'onSecondaryContainer/secondaryContainer',
  'onTertiary/tertiary',
  'onTertiaryContainer/tertiaryContainer',
  'onError/error',
  'onSurface/surface',
  'onSurfaceVariant/surface',
  'onSurface/surfaceContainerHighest',
];

/// Returns [scheme] with every foreground in [kCheckedPairs] meeting WCAG AA
/// against its background, plus a report. Foregrounds that fail are moved
/// toward black or white (whichever contrasts more) until they pass.
(ColorScheme, ContrastReport) ensureReadable(ColorScheme scheme) {
  final m = _schemeMap(scheme);
  final checks = <ContrastCheck>[];
  for (final pair in kCheckedPairs) {
    final parts = pair.split('/');
    final fg = m[parts[0]]!;
    final bg = m[parts[1]]!;
    var ratio = contrastRatio(fg, bg);
    var adjusted = false;
    if (ratio < 4.5) {
      final target =
          contrastRatio(Colors.white, bg) >= contrastRatio(Colors.black, bg)
              ? Colors.white
              : Colors.black;
      var fixed = fg;
      for (var t = 0.1; t <= 1.0001; t += 0.1) {
        fixed = Color.lerp(fg, target, t)!;
        if (contrastRatio(fixed, bg) >= 4.5) break;
      }
      m[parts[0]] = fixed;
      ratio = contrastRatio(fixed, bg);
      adjusted = true;
    }
    checks.add(ContrastCheck(pair: pair, ratio: ratio, adjusted: adjusted));
  }
  final out = scheme.copyWith(
    onPrimary: m['onPrimary'],
    onPrimaryContainer: m['onPrimaryContainer'],
    onSecondary: m['onSecondary'],
    onSecondaryContainer: m['onSecondaryContainer'],
    onTertiary: m['onTertiary'],
    onTertiaryContainer: m['onTertiaryContainer'],
    onError: m['onError'],
    onSurface: m['onSurface'],
    onSurfaceVariant: m['onSurfaceVariant'],
  );
  return (out, ContrastReport(checks));
}

Map<String, Color> _schemeMap(ColorScheme s) => <String, Color>{
      'primary': s.primary,
      'onPrimary': s.onPrimary,
      'primaryContainer': s.primaryContainer,
      'onPrimaryContainer': s.onPrimaryContainer,
      'secondary': s.secondary,
      'onSecondary': s.onSecondary,
      'secondaryContainer': s.secondaryContainer,
      'onSecondaryContainer': s.onSecondaryContainer,
      'tertiary': s.tertiary,
      'onTertiary': s.onTertiary,
      'tertiaryContainer': s.tertiaryContainer,
      'onTertiaryContainer': s.onTertiaryContainer,
      'error': s.error,
      'onError': s.onError,
      'surface': s.surface,
      'onSurface': s.onSurface,
      'onSurfaceVariant': s.onSurfaceVariant,
      'surfaceContainerHighest': s.surfaceContainerHighest,
    };
