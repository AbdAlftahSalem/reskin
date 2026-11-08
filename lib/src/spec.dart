import 'package:flutter/material.dart';

/// Maps a font family name to a [TextTheme]. Use it to plug in google_fonts
/// or bundled fonts: `(family, base) => GoogleFonts.getTextTheme(family, base)`.
typedef ReskinFontResolver = TextTheme Function(String family, TextTheme base);

/// A complete theme direction: light + dark schemes, fonts and corner radius.
@immutable
class ReskinTheme {
  const ReskinTheme({
    required this.name,
    required this.light,
    required this.dark,
    this.headingFont,
    this.bodyFont,
    this.radius = 12,
    this.source = 'offline',
    this.prompt,
    this.lightFixes = 0,
    this.darkFixes = 0,
  });

  /// Builds a theme from one seed color with Material 3's tonal palettes.
  factory ReskinTheme.fromSeed(
    Color seed, {
    String name = 'Seed',
    DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
    String? headingFont,
    String? bodyFont,
    double radius = 12,
  }) {
    return ReskinTheme(
      name: name,
      light:
          ColorScheme.fromSeed(seedColor: seed, dynamicSchemeVariant: variant),
      dark: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          dynamicSchemeVariant: variant),
      headingFont: headingFont,
      bodyFont: bodyFont,
      radius: radius,
      source: 'seed',
    );
  }

  final String name;
  final ColorScheme light;
  final ColorScheme dark;

  /// Font for display/headline/title styles. Null keeps the app's font.
  final String? headingFont;

  /// Font for body/label styles. Null keeps the app's font.
  final String? bodyFont;

  /// Corner radius applied to cards, buttons, inputs, chips and dialogs.
  final double radius;

  /// `offline`, `seed`, `image`, `gemini`, `openai`, `original`...
  final String source;

  /// The prompt this theme came from, if any.
  final String? prompt;

  /// How many colors of [light] reskin changed to reach WCAG AA (text 4.5:1,
  /// accents 3:1) when it built this theme. 0 when nothing needed fixing.
  final int lightFixes;

  /// Same as [lightFixes] for [dark].
  final int darkFixes;

  /// [lightFixes] or [darkFixes].
  int fixesFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkFixes : lightFixes;

  ColorScheme scheme(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// A full [ThemeData] for [brightness]. [base] supplies the app's original
  /// text theme so sizes and weights are kept.
  ThemeData toThemeData(
    Brightness brightness, {
    ThemeData? base,
    ReskinFontResolver? fontResolver,
  }) {
    final cs = scheme(brightness);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    var theme = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: bodyFont,
    );
    var text = theme.textTheme;
    if (bodyFont != null && fontResolver != null) {
      text = fontResolver(bodyFont!, text);
    }
    if (headingFont != null) {
      TextStyle? h(TextStyle? s) => s?.copyWith(fontFamily: headingFont);
      if (fontResolver != null) {
        final heading = fontResolver(headingFont!, text);
        text = text.copyWith(
          displayLarge: heading.displayLarge,
          displayMedium: heading.displayMedium,
          displaySmall: heading.displaySmall,
          headlineLarge: heading.headlineLarge,
          headlineMedium: heading.headlineMedium,
          headlineSmall: heading.headlineSmall,
          titleLarge: heading.titleLarge,
        );
      } else {
        text = text.copyWith(
          displayLarge: h(text.displayLarge),
          displayMedium: h(text.displayMedium),
          displaySmall: h(text.displaySmall),
          headlineLarge: h(text.headlineLarge),
          headlineMedium: h(text.headlineMedium),
          headlineSmall: h(text.headlineSmall),
          titleLarge: h(text.titleLarge),
        );
      }
    }
    theme = theme.copyWith(
      textTheme: text,
      cardTheme: CardThemeData(shape: shape, clipBehavior: Clip.antiAlias),
      filledButtonTheme:
          FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: shape)),
      chipTheme: ChipThemeData(shape: shape),
      dialogTheme: DialogThemeData(shape: shape),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
    return theme;
  }

  ReskinTheme copyWith({
    String? name,
    ColorScheme? light,
    ColorScheme? dark,
    String? headingFont,
    String? bodyFont,
    double? radius,
    String? source,
    String? prompt,
    int? lightFixes,
    int? darkFixes,
  }) =>
      ReskinTheme(
        name: name ?? this.name,
        light: light ?? this.light,
        dark: dark ?? this.dark,
        headingFont: headingFont ?? this.headingFont,
        bodyFont: bodyFont ?? this.bodyFont,
        radius: radius ?? this.radius,
        source: source ?? this.source,
        prompt: prompt ?? this.prompt,
        lightFixes: lightFixes ?? this.lightFixes,
        darkFixes: darkFixes ?? this.darkFixes,
      );

  /// Compact JSON used by the VM service extensions and the MCP server.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'source': source,
        if (prompt != null) 'prompt': prompt,
        'headingFont': headingFont,
        'bodyFont': bodyFont,
        'radius': radius,
        'light': schemeToJson(light),
        'dark': schemeToJson(dark),
      };

  @override
  String toString() => 'ReskinTheme($name, $source)';
}

/// Hex like `#FF1B2A4A`.
String colorHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Map<String, String> schemeToJson(ColorScheme s) => <String, String>{
      'primary': colorHex(s.primary),
      'onPrimary': colorHex(s.onPrimary),
      'secondary': colorHex(s.secondary),
      'tertiary': colorHex(s.tertiary),
      'surface': colorHex(s.surface),
      'onSurface': colorHex(s.onSurface),
      'error': colorHex(s.error),
    };
