import 'package:flutter/material.dart';

/// Bunn's own brand theme: deep pine green, warm paper surfaces, Manrope.
const Color bunnSeed = Color(0xFF2F5D50);

ThemeData _build(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: bunnSeed, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor:
          WidgetStatePropertyAll<Color>(scheme.surfaceContainerHigh),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    ),
  );
}

final ThemeData bunnLight = _build(Brightness.light);
final ThemeData bunnDark = _build(Brightness.dark);

/// Font families bundled in pubspec.yaml; the AI may only pick these.
const List<String> bundledFonts = <String>[
  'Manrope',
  'Inter',
  'El Messiri',
  'Cormorant Garamond',
  'JetBrains Mono',
  'DejaVu Serif',
];
