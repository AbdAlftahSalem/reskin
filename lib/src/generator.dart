import 'package:flutter/material.dart';

import 'contrast.dart';
import 'spec.dart';

/// What the developer asked for: a text prompt, a seed color, a logo image,
/// or a combination.
@immutable
class ReskinPrompt {
  const ReskinPrompt({this.text, this.seed, this.image, this.count = 4});

  const ReskinPrompt.text(String this.text, {this.count = 4})
      : seed = null,
        image = null;

  const ReskinPrompt.seed(Color this.seed, {this.count = 4})
      : text = null,
        image = null;

  const ReskinPrompt.image(ImageProvider this.image,
      {this.text, this.count = 4})
      : seed = null;

  final String? text;
  final Color? seed;

  /// A logo or screenshot. Its dominant color becomes the seed.
  final ImageProvider? image;

  /// How many variants to return.
  final int count;

  String get label => text ?? (seed != null ? colorHex(seed!) : 'logo');
}

/// Turns a [ReskinPrompt] into theme variants. Implement this to plug in any
/// model; see [GeminiThemeProvider] and [OpenAIThemeProvider].
abstract class ReskinThemeProvider {
  const ReskinThemeProvider();

  /// Short name shown in the panel, like `offline` or `gemini`.
  String get name;

  Future<List<ReskinTheme>> generate(ReskinPrompt prompt);
}

/// Deterministic, offline, no API key. Maps color and mood words
/// ("gold on navy", "ramadan", "ocean", "minimal") to seeds, fonts and
/// radius, then builds Material 3 schemes with [ColorScheme.fromSeed].
/// The same prompt always gives the same themes.
class OfflineThemeProvider extends ReskinThemeProvider {
  const OfflineThemeProvider();

  @override
  String get name => 'offline';

  @override
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    if (prompt.image != null) {
      final light =
          await ColorScheme.fromImageProvider(provider: prompt.image!);
      final dark = await ColorScheme.fromImageProvider(
          provider: prompt.image!, brightness: Brightness.dark);
      final seed = light.primary;
      final intent = prompt.text != null
          ? parsePrompt(prompt.text!)
          : PromptIntent(seed: seed, title: 'Logo');
      final first = buildTheme(
        intent.copyWithSeed(seed),
        DynamicSchemeVariant.fidelity,
        name: '${intent.title} · From logo',
        source: 'image',
      ).copyWith(light: light, dark: dark);
      final rest = variantsFor(intent.copyWithSeed(seed), prompt.count - 1,
          source: 'image', prompt: prompt.text);
      return <ReskinTheme>[_readable(first), ...rest];
    }
    final intent = prompt.text != null
        ? parsePrompt(prompt.text!)
        : PromptIntent(seed: prompt.seed!, title: colorHex(prompt.seed!));
    final withSeed =
        prompt.seed != null ? intent.copyWithSeed(prompt.seed!) : intent;
    return variantsFor(withSeed, prompt.count,
        source: prompt.text != null ? 'offline' : 'seed', prompt: prompt.text);
  }
}

/// What the offline parser understood from a prompt.
@immutable
class PromptIntent {
  const PromptIntent({
    required this.seed,
    required this.title,
    this.accent,
    this.background,
    this.headingFont,
    this.bodyFont,
    this.radius = 12,
    this.matched = const <String>[],
  });

  /// Main brand color.
  final Color seed;

  /// Second color from "X on Y" or a second color word.
  final Color? accent;

  /// Background color from "... on Y".
  final Color? background;
  final String title;
  final String? headingFont;
  final String? bodyFont;
  final double radius;

  /// Keywords that were recognised (for debugging and tests).
  final List<String> matched;

  PromptIntent copyWithSeed(Color s) => PromptIntent(
        seed: s,
        title: title,
        accent: accent,
        background: background,
        headingFont: headingFont,
        bodyFont: bodyFont,
        radius: radius,
        matched: matched,
      );
}

/// Color words the offline provider understands.
const Map<String, Color> kColorWords = <String, Color>{
  'gold': Color(0xFFD4AF37),
  'golden': Color(0xFFD4AF37),
  'navy': Color(0xFF1B2A4A),
  'midnight': Color(0xFF14213D),
  'black': Color(0xFF121212),
  'white': Color(0xFFF5F5F5),
  'cream': Color(0xFFF3E9D2),
  'beige': Color(0xFFE8D8B9),
  'sand': Color(0xFFC8A165),
  'brown': Color(0xFF6D4C41),
  'coffee': Color(0xFF6F4E37),
  'mocha': Color(0xFF7B5E57),
  'red': Color(0xFFD32F2F),
  'crimson': Color(0xFFB71C1C),
  'maroon': Color(0xFF7B1E3A),
  'burgundy': Color(0xFF800020),
  'coral': Color(0xFFFF6F61),
  'peach': Color(0xFFFFAB91),
  'orange': Color(0xFFF57C00),
  'amber': Color(0xFFFFB300),
  'yellow': Color(0xFFFBC02D),
  'lime': Color(0xFFAFB42B),
  'olive': Color(0xFF6B8E23),
  'green': Color(0xFF2E7D32),
  'emerald': Color(0xFF009B77),
  'mint': Color(0xFF3EB489),
  'teal': Color(0xFF00897B),
  'turquoise': Color(0xFF1ABC9C),
  'cyan': Color(0xFF00ACC1),
  'sky': Color(0xFF4FC3F7),
  'blue': Color(0xFF1E63D6),
  'indigo': Color(0xFF3949AB),
  'purple': Color(0xFF7B1FA2),
  'violet': Color(0xFF6A3FD0),
  'lavender': Color(0xFF9C8ADE),
  'pink': Color(0xFFE91E63),
  'rose': Color(0xFFE11D48),
  'magenta': Color(0xFFC2185B),
  'slate': Color(0xFF475569),
  'grey': Color(0xFF616161),
  'gray': Color(0xFF616161),
  'silver': Color(0xFF9E9E9E),
};

@immutable
class _Mood {
  const _Mood(this.seed,
      {this.accent,
      this.background,
      this.heading,
      this.body,
      this.radius = 12});
  final Color seed;
  final Color? accent;
  final Color? background;
  final String? heading;
  final String? body;
  final double radius;
}

/// Mood words: each sets a seed and a font/radius personality.
const Map<String, _Mood> _moods = <String, _Mood>{
  'ramadan': _Mood(Color(0xFF1B2A4A),
      accent: Color(0xFFD4AF37),
      background: Color(0xFF1B2A4A),
      heading: 'El Messiri',
      radius: 18),
  'eid': _Mood(Color(0xFF00695C),
      accent: Color(0xFFD4AF37), heading: 'El Messiri', radius: 18),
  'luxury': _Mood(Color(0xFF1C1C1C),
      accent: Color(0xFFD4AF37), heading: 'Cormorant Garamond', radius: 6),
  'elegant': _Mood(Color(0xFF3E2C41),
      accent: Color(0xFFC9A96E), heading: 'Cormorant Garamond', radius: 8),
  'premium': _Mood(Color(0xFF212121),
      accent: Color(0xFFD4AF37), heading: 'Cormorant Garamond', radius: 8),
  'ocean': _Mood(Color(0xFF0277BD),
      accent: Color(0xFF26C6DA), heading: 'Manrope', radius: 20),
  'sea': _Mood(Color(0xFF0277BD), accent: Color(0xFF26C6DA), radius: 20),
  'beach': _Mood(Color(0xFF00ACC1),
      accent: Color(0xFFFFCC80), heading: 'Manrope', radius: 22),
  'forest': _Mood(Color(0xFF2E7D32), accent: Color(0xFF8D6E63), radius: 14),
  'nature': _Mood(Color(0xFF388E3C), accent: Color(0xFFA1887F), radius: 16),
  'eco': _Mood(Color(0xFF43A047), radius: 16),
  'sunset': _Mood(Color(0xFFFF7043),
      accent: Color(0xFF7E57C2), heading: 'Manrope', radius: 20),
  'coffee': _Mood(Color(0xFF6F4E37),
      accent: Color(0xFFF3E9D2), heading: 'Cormorant Garamond', radius: 14),
  'cafe': _Mood(Color(0xFF6F4E37), accent: Color(0xFFF3E9D2), radius: 14),
  'minimal':
      _Mood(Color(0xFF455A64), heading: 'Inter', body: 'Inter', radius: 4),
  'clean': _Mood(Color(0xFF546E7A), heading: 'Inter', body: 'Inter', radius: 6),
  'playful': _Mood(Color(0xFFE91E63),
      accent: Color(0xFFFFC107), heading: 'Manrope', radius: 28),
  'fun': _Mood(Color(0xFFFF4081), accent: Color(0xFFFFD740), radius: 26),
  'kids': _Mood(Color(0xFFFF7043), accent: Color(0xFF29B6F6), radius: 28),
  'candy': _Mood(Color(0xFFEC407A), accent: Color(0xFF80DEEA), radius: 28),
  'tech': _Mood(Color(0xFF00B8D4),
      background: Color(0xFF0B0F14), heading: 'JetBrains Mono', radius: 8),
  'cyber': _Mood(Color(0xFF00E5FF),
      accent: Color(0xFFFF00E5),
      background: Color(0xFF07080D),
      heading: 'JetBrains Mono',
      radius: 4),
  'neon': _Mood(Color(0xFF39FF14),
      background: Color(0xFF0A0A0A), heading: 'JetBrains Mono', radius: 6),
  'gaming': _Mood(Color(0xFF7C4DFF),
      accent: Color(0xFF00E676), heading: 'JetBrains Mono', radius: 10),
  'fintech':
      _Mood(Color(0xFF1565C0), heading: 'Inter', body: 'Inter', radius: 12),
  'bank': _Mood(Color(0xFF0D47A1), heading: 'Inter', body: 'Inter', radius: 8),
  'corporate':
      _Mood(Color(0xFF1A237E), heading: 'Inter', body: 'Inter', radius: 6),
  'business':
      _Mood(Color(0xFF283593), heading: 'Inter', body: 'Inter', radius: 8),
  'health': _Mood(Color(0xFF00897B), heading: 'Manrope', radius: 16),
  'medical': _Mood(Color(0xFF0288D1), heading: 'Manrope', radius: 12),
  'food': _Mood(Color(0xFFE53935), accent: Color(0xFFFFB300), radius: 18),
  'restaurant': _Mood(Color(0xFFC62828), accent: Color(0xFFFFB300), radius: 16),
  'desert': _Mood(Color(0xFFC8A165), accent: Color(0xFF8D4004), radius: 14),
  'olive': _Mood(Color(0xFF6B8E23), accent: Color(0xFFC8A165), radius: 14),
  'spring': _Mood(Color(0xFF7CB342), accent: Color(0xFFF48FB1), radius: 20),
  'retro': _Mood(Color(0xFFD84315),
      accent: Color(0xFF00897B), heading: 'DejaVu Serif', radius: 10),
  'vintage': _Mood(Color(0xFF8D6E63),
      accent: Color(0xFFD7CCC8), heading: 'DejaVu Serif', radius: 8),
  'night': _Mood(Color(0xFF283593), background: Color(0xFF14213D), radius: 16),
};

/// Parses a free-text prompt. Understands color words, mood words, and the
/// pattern "X on Y" (X = accent, Y = background/brand), in any order.
PromptIntent parsePrompt(String text) {
  final lower = text.toLowerCase();
  final words =
      RegExp(r'[a-z]+').allMatches(lower).map((m) => m.group(0)!).toList();
  final matched = <String>[];
  Color? seed;
  Color? accent;
  Color? background;
  String? heading;
  String? body;
  double? radius;

  for (final w in words) {
    final mood = _moods[w];
    if (mood != null) {
      matched.add(w);
      seed ??= mood.seed;
      accent ??= mood.accent;
      background ??= mood.background;
      heading ??= mood.heading;
      body ??= mood.body;
      radius ??= mood.radius;
    }
  }

  // "gold on navy" → accent gold, background + seed navy.
  final on = RegExp(r'([a-z]+)\s+on\s+([a-z]+)').firstMatch(lower);
  if (on != null &&
      kColorWords.containsKey(on.group(1)) &&
      kColorWords.containsKey(on.group(2))) {
    accent = kColorWords[on.group(1)];
    background = kColorWords[on.group(2)];
    seed = background;
    matched.add('${on.group(1)} on ${on.group(2)}');
  } else {
    final colors = <Color>[
      for (final w in words)
        if (kColorWords.containsKey(w)) kColorWords[w]!,
    ];
    for (final w in words) {
      if (kColorWords.containsKey(w)) matched.add(w);
    }
    if (colors.isNotEmpty) {
      seed = colors.first;
      if (colors.length > 1) accent = colors[1];
    }
  }

  // Unknown words: derive a stable hue from the text so it is never random.
  seed ??=
      HSLColor.fromAHSL(1, (_stableHash(lower) % 360).toDouble(), 0.55, 0.45)
          .toColor();

  if (lower.contains('round') || lower.contains('soft')) radius = 24;
  if (lower.contains('sharp') || lower.contains('square')) radius = 2;
  if (lower.contains('serif')) heading = 'Cormorant Garamond';
  if (lower.contains('mono')) heading = 'JetBrains Mono';

  return PromptIntent(
    seed: seed,
    accent: accent,
    background: background,
    title: on != null &&
            matched.contains('${on.group(1)} on ${on.group(2)}') &&
            words.length <= 3
        ? '${_cap(on.group(1)!)} on ${_cap(on.group(2)!)}'
        : _title(text),
    headingFont: heading,
    bodyFont: body,
    radius: radius ?? 12,
    matched: matched,
  );
}

String _cap(String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

int _stableHash(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

String _title(String text) {
  final words = text
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase());
  final t = words.join(' ');
  return t.isEmpty ? 'Custom' : t;
}

const List<(String, DynamicSchemeVariant, double, String?)> _variantRecipes =
    <(String, DynamicSchemeVariant, double, String?)>[
  ('Classic', DynamicSchemeVariant.tonalSpot, 0, null),
  ('Vivid', DynamicSchemeVariant.vibrant, 4, 'Manrope'),
  ('Faithful', DynamicSchemeVariant.fidelity, -4, null),
  ('Expressive', DynamicSchemeVariant.expressive, 8, 'Cormorant Garamond'),
  ('Calm', DynamicSchemeVariant.neutral, 2, 'Inter'),
  ('Content', DynamicSchemeVariant.content, 0, null),
];

/// [count] contrast-checked variants for one intent.
List<ReskinTheme> variantsFor(PromptIntent intent, int count,
    {String source = 'offline', String? prompt}) {
  final out = <ReskinTheme>[];
  for (var i = 0; i < count; i++) {
    final r = _variantRecipes[i % _variantRecipes.length];
    final t = buildTheme(
      intent,
      r.$2,
      name: '${intent.title} · ${r.$1}',
      source: source,
      radiusDelta: r.$3,
      altHeading: i == 0 ? null : r.$4,
    );
    out.add(_readable(t.copyWith(prompt: prompt)));
  }
  return out;
}

/// One theme for [intent] with Material 3 [variant].
ReskinTheme buildTheme(
  PromptIntent intent,
  DynamicSchemeVariant variant, {
  required String name,
  String source = 'offline',
  double radiusDelta = 0,
  String? altHeading,
}) {
  var light = ColorScheme.fromSeed(
      seedColor: intent.seed, dynamicSchemeVariant: variant);
  var dark = ColorScheme.fromSeed(
      seedColor: intent.accent != null && intent.background != null
          ? intent.accent!
          : intent.seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: variant);

  final accent = intent.accent;
  if (accent != null) {
    final acc = ColorScheme.fromSeed(
        seedColor: accent, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    final accDark = ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    light = light.copyWith(
      secondary: acc.primary,
      onSecondary: acc.onPrimary,
      secondaryContainer: acc.primaryContainer,
      onSecondaryContainer: acc.onPrimaryContainer,
    );
    dark = dark.copyWith(
      secondary: accDark.primary,
      onSecondary: accDark.onPrimary,
      secondaryContainer: accDark.primaryContainer,
      onSecondaryContainer: accDark.onPrimaryContainer,
    );
  }
  final bg = intent.background;
  if (bg != null) {
    Color mix(double t) => Color.lerp(bg, Colors.white, t)!;
    final deep = Color.lerp(bg, Colors.black, 0.35)!;
    dark = dark.copyWith(
      surface: deep,
      surfaceDim: Color.lerp(bg, Colors.black, 0.45),
      surfaceBright: mix(0.12),
      surfaceContainerLowest: Color.lerp(bg, Colors.black, 0.5),
      surfaceContainerLow: Color.lerp(bg, Colors.black, 0.2),
      surfaceContainer: bg,
      surfaceContainerHigh: mix(0.06),
      surfaceContainerHighest: mix(0.12),
      onSurface: const Color(0xFFF1ECE1),
      onSurfaceVariant: const Color(0xFFC9C3B6),
    );
  }
  return ReskinTheme(
    name: name,
    light: light,
    dark: dark,
    headingFont: altHeading ?? intent.headingFont,
    bodyFont: intent.bodyFont,
    radius: (intent.radius + radiusDelta).clamp(0, 32).toDouble(),
    source: source,
  );
}

ReskinTheme _readable(ReskinTheme t) {
  final (light, _) = ensureReadable(t.light);
  final (dark, _) = ensureReadable(t.dark);
  return t.copyWith(light: light, dark: dark);
}
