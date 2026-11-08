import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'contrast.dart';
import 'generator.dart';
import 'spec.dart';

/// The instruction every AI provider sends. The model picks the colors,
/// fonts and radius; reskin builds full Material 3 schemes from them,
/// validates the answer and fixes contrast itself.
const String kReskinSystemPrompt = '''
You are a senior product designer. You turn a short brief into Flutter Material 3 app themes.
The brief can be in any language (Arabic, English, ...). Read its meaning, culture and mood, not only color words: "a forest cabin" suggests pine greens and warm wood; "a hospital" suggests calm, trustworthy blues or teals.
Return JSON only. Give exactly the number of variants asked for. They must be clearly different from each other and all faithful to the brief.
Prefer refined, designed colors over pure web named colors (#000080, #FFD700, #00FFFF), unless the brief asks for neon.
For each variant:
- name: 1 to 3 words, in the same language as the brief (an English brief gets English names).
- light: colors for light mode. primary = the brand color of buttons and highlights. secondary = an accent that works with primary. background = the page color. surface = the card color, close to but not equal to background. In light mode, background and surface are light, unless the brief clearly asks for a dark look.
- dark: the same identity in dark mode. primary and secondary keep the hue of the light ones, as lighter tones bright enough to read on a dark page; background and surface are dark, tinted toward the theme.
- headingFont and bodyFont: Google Fonts family names. If the brief is in Arabic, prefer fonts that support Arabic script.
- radius: corner radius in logical pixels, 0 to 28. Sharp or technical looks are small, soft or friendly looks are large.
Every color is a 6-digit hex string like "#1B2A4A".
''';

Map<String, Object?> _paletteSchema(String type, String string) =>
    <String, Object?>{
      'type': type,
      'properties': <String, Object?>{
        for (final k in kPaletteKeys) k: <String, String>{'type': string},
      },
      'required': kPaletteKeys,
      if (type == 'object') 'additionalProperties': false,
    };

Map<String, Object?> _responseSchema({required bool openApi}) {
  final o = openApi ? 'OBJECT' : 'object';
  final s = openApi ? 'STRING' : 'string';
  final n = openApi ? 'NUMBER' : 'number';
  final a = openApi ? 'ARRAY' : 'array';
  const fields = <String>[
    'name',
    'light',
    'dark',
    'headingFont',
    'bodyFont',
    'radius'
  ];
  return <String, Object?>{
    'type': o,
    'properties': <String, Object?>{
      'variants': <String, Object?>{
        'type': a,
        'items': <String, Object?>{
          'type': o,
          'properties': <String, Object?>{
            'name': <String, String>{'type': s},
            'light': _paletteSchema(o, s),
            'dark': _paletteSchema(o, s),
            'headingFont': <String, String>{'type': s},
            'bodyFont': <String, String>{'type': s},
            'radius': <String, String>{'type': n},
          },
          'required': fields,
          if (!openApi) 'additionalProperties': false,
        },
      },
    },
    'required': <String>['variants'],
    if (!openApi) 'additionalProperties': false,
  };
}

/// The palette keys every AI variant has, for light and for dark.
const List<String> kPaletteKeys = <String>[
  'primary',
  'secondary',
  'background',
  'surface'
];

/// Gemini `responseSchema` (OpenAPI subset) for [kReskinSystemPrompt].
final Map<String, Object?> kReskinGeminiSchema = _responseSchema(openApi: true);

/// JSON Schema for OpenAI structured outputs (`json_schema`, strict).
final Map<String, Object?> kReskinJsonSchema = _responseSchema(openApi: false);

/// Fonts known to carry Arabic glyphs. Used to steer the model when the
/// prompt is Arabic and you restrict it to the fonts your app bundles.
const Set<String> kArabicFonts = <String>{
  'almarai',
  'amiri',
  'baloo bhaijaan 2',
  'cairo',
  'changa',
  'el messiri',
  'harmattan',
  'ibm plex sans arabic',
  'lalezar',
  'lateef',
  'mada',
  'markazi text',
  'noto kufi arabic',
  'noto naskh arabic',
  'noto sans arabic',
  'readex pro',
  'reem kufi',
  'rubik',
  'scheherazade new',
  'tajawal',
  'vazirmatn',
};

/// True when [text] contains Arabic script.
bool containsArabic(String text) =>
    RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);

/// The user message sent with [kReskinSystemPrompt].
String reskinUserMessage(ReskinPrompt p, {List<String>? fonts}) {
  final b = StringBuffer('Brief: ${p.text ?? 'a modern app'}\n');
  if (p.seed != null) {
    b.writeln('Brand color that must stay the primary: ${colorHex(p.seed!)}');
  }
  b.writeln('Variants: ${p.count}');
  if (fonts != null && fonts.isNotEmpty) {
    b.writeln('Use only these fonts: ${fonts.join(', ')}.');
    if (containsArabic(p.text ?? '')) {
      final ar =
          fonts.where((f) => kArabicFonts.contains(f.toLowerCase())).toList();
      if (ar.isNotEmpty) {
        b.writeln('Of these, Arabic script is supported by: ${ar.join(', ')}.');
      }
    }
  }
  return b.toString().trim();
}

/// Thrown when a model's answer is not a usable theme list. [problems]
/// says what was wrong with each rejected variant.
class ReskinResponseException extends FormatException {
  const ReskinResponseException(super.message,
      [this.problems = const <String>[]]);

  final List<String> problems;

  @override
  String toString() => problems.isEmpty
      ? 'ReskinResponseException: $message'
      : 'ReskinResponseException: $message (${problems.join('; ')})';
}

/// One mode's colors as the model returned them.
@immutable
class AiPalette {
  const AiPalette(
      {required this.primary, this.secondary, this.background, this.surface});

  final Color primary;
  final Color? secondary;
  final Color? background;
  final Color? surface;

  @override
  String toString() => <String>[
        'primary ${colorHex(primary)}',
        if (secondary != null) 'secondary ${colorHex(secondary!)}',
        if (background != null) 'background ${colorHex(background!)}',
        if (surface != null) 'surface ${colorHex(surface!)}',
      ].join(', ');
}

/// One validated variant from a model answer, before reskin builds schemes.
@immutable
class AiVariant {
  const AiVariant({
    required this.name,
    required this.light,
    this.dark,
    this.headingFont,
    this.bodyFont,
    this.radius = 12,
  });

  final String name;
  final AiPalette light;

  /// Null when the model gave no dark palette; reskin derives one.
  final AiPalette? dark;
  final String? headingFont;
  final String? bodyFont;
  final double radius;

  /// Full light + dark schemes, contrast-checked (WCAG AA).
  ReskinTheme toTheme({String source = 'ai', String? prompt}) {
    final l = schemeFromPalette(light, Brightness.light);
    final d = dark != null
        ? schemeFromPalette(dark!, Brightness.dark)
        : _derivedDark(light);
    final (lightScheme, lightFixes) = makeReadable(l);
    final (darkScheme, darkFixes) = makeReadable(d);
    return ReskinTheme(
      name: name,
      light: lightScheme,
      dark: darkScheme,
      lightFixes: lightFixes,
      darkFixes: darkFixes,
      headingFont: headingFont,
      bodyFont: bodyFont,
      radius: radius,
      source: source,
      prompt: prompt,
    );
  }

  static ColorScheme _derivedDark(AiPalette p) {
    final seeded = ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    return schemeFromPalette(
        AiPalette(primary: seeded.primary, secondary: p.secondary),
        Brightness.dark);
  }
}

Color _on(Color bg) {
  // Pick near-white or near-black text, whichever reads better, tinted by bg.
  final white = Color.lerp(Colors.white, bg, 0.06)!;
  final black = Color.lerp(const Color(0xFF111111), bg, 0.12)!;
  return contrastRatio(white, bg) >= contrastRatio(black, bg) ? white : black;
}

/// A Material 3 [ColorScheme] that uses the model's exact colors for
/// primary, secondary, background (surface) and cards
/// (surfaceContainerLow), filling every other role from the primary's
/// tonal palette. Contrast is fixed afterwards by [ensureReadable].
ColorScheme schemeFromPalette(AiPalette p, Brightness brightness) {
  var cs = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
  cs = cs.copyWith(primary: p.primary, onPrimary: _on(p.primary));
  final sec = p.secondary;
  if (sec != null) {
    final acc = ColorScheme.fromSeed(
        seedColor: sec,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    cs = cs.copyWith(
      secondary: sec,
      onSecondary: _on(sec),
      secondaryContainer: acc.primaryContainer,
      onSecondaryContainer: acc.onPrimaryContainer,
      // Keep the third color in the model's accent family instead of the
      // hue-rotated tertiary Material would invent (green next to coffee).
      tertiary: acc.secondary,
      onTertiary: acc.onSecondary,
      tertiaryContainer: acc.secondaryContainer,
      onTertiaryContainer: acc.onSecondaryContainer,
    );
  }
  final bg = p.background;
  if (bg != null) {
    final onBg = _on(bg);
    final card = p.surface ?? Color.lerp(bg, onBg, 0.04)!;
    Color toward(double t) => Color.lerp(card, onBg, t)!;
    cs = cs.copyWith(
      surface: bg,
      onSurface: onBg,
      onSurfaceVariant: Color.lerp(onBg, bg, 0.28),
      surfaceDim: Color.lerp(bg, Colors.black, 0.08),
      surfaceBright: Color.lerp(bg, Colors.white, 0.08),
      surfaceContainerLowest: Color.lerp(bg, card, 0.5),
      surfaceContainerLow: card,
      surfaceContainer: toward(0.04),
      surfaceContainerHigh: toward(0.08),
      surfaceContainerHighest: toward(0.12),
      outline: Color.lerp(onBg, bg, 0.5),
      outlineVariant: Color.lerp(onBg, bg, 0.78),
      inverseSurface: onBg,
      onInverseSurface: bg,
    );
  } else if (p.surface != null) {
    cs = cs.copyWith(surfaceContainerLow: p.surface);
  }
  return cs;
}

/// `#RRGGBB`, `RRGGBB`, `#AARRGGBB` or `0xAARRGGBB`. Null if not a color.
Color? parseHexColor(String? s) {
  if (s == null) return null;
  var h = s.trim().toUpperCase().replaceFirst('#', '').replaceFirst('0X', '');
  if (!RegExp(r'^[0-9A-F]{6}([0-9A-F]{2})?$').hasMatch(h)) return null;
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

final RegExp _fontName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 \-]{0,47}$');

/// Strictly validates a model answer and returns its usable variants.
///
/// Accepts `{"variants":[...]}` or a bare list, optionally inside a
/// ```json fence. Each variant needs a non-empty `name` (max 40 chars) and a
/// valid `light.primary` hex color; every other color, when present, must be
/// valid hex too, or the variant is rejected. `radius` must be a number
/// (clamped to 0..32). Fonts that are not plausible family names, or are
/// outside [allowedFonts] when given, become null (the app keeps its font).
/// The older flat shape (`seed`, `accent`, `background`) is still read.
///
/// Throws [ReskinResponseException] when nothing usable is left.
List<AiVariant> parseAiVariants(String raw,
    {int? max, List<String>? allowedFonts}) {
  var text = raw.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  if (text.isEmpty) {
    throw const ReskinResponseException('The model returned an empty answer.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw ReskinResponseException(
        'The model answer is not JSON.', <String>[e.message]);
  }
  final Object? list =
      decoded is Map<String, dynamic> ? decoded['variants'] : decoded;
  if (list is! List<dynamic>) {
    throw const ReskinResponseException('No "variants" list in the answer.');
  }
  final allowed = allowedFonts?.map((f) => f.toLowerCase()).toSet();
  final problems = <String>[];
  final out = <AiVariant>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    try {
      if (item is! Map<String, dynamic>) throw 'not an object';
      out.add(_variant(item, allowed));
    } catch (e) {
      problems.add('variant ${i + 1}: $e');
    }
    if (max != null && out.length >= max) break;
  }
  if (out.isEmpty) {
    throw ReskinResponseException(
        'The model returned no usable variants.', problems);
  }
  return out;
}

AiVariant _variant(Map<String, dynamic> m, Set<String>? allowedFonts) {
  final rawName = m['name'];
  if (rawName is! String || rawName.trim().isEmpty) throw 'missing name';
  var name = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.length > 40) name = name.substring(0, 40).trim();

  Color? color(Object? v, String key, {bool required = false}) {
    if (v == null) {
      if (required) throw 'missing $key';
      return null;
    }
    if (v is! String) throw '$key is not a string';
    final c = parseHexColor(v);
    if (c == null) throw '$key "$v" is not a hex color';
    return c.withAlpha(0xFF);
  }

  AiPalette? palette(Object? v, String mode, {required bool required}) {
    if (v == null) {
      if (required) throw 'missing $mode palette';
      return null;
    }
    if (v is! Map<String, dynamic>) throw '$mode is not an object';
    return AiPalette(
      primary:
          color(v['primary'] ?? v['seed'], '$mode.primary', required: true)!,
      secondary: color(v['secondary'] ?? v['accent'], '$mode.secondary'),
      background: color(v['background'], '$mode.background'),
      surface: color(v['surface'], '$mode.surface'),
    );
  }

  final AiPalette light;
  AiPalette? dark;
  if (m['light'] != null || m['seed'] == null) {
    light = palette(m['light'], 'light', required: true)!;
    dark = palette(m['dark'], 'dark', required: false);
  } else {
    // Legacy flat shape: seed/accent/background (background = dark surface).
    final seed = color(m['seed'], 'seed', required: true)!;
    final accent = color(m['accent'], 'accent');
    final bg = color(m['background'], 'background');
    light = AiPalette(primary: seed, secondary: accent);
    if (bg != null) {
      final d = ColorScheme.fromSeed(
          seedColor: accent ?? seed,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
      dark = AiPalette(
          primary: d.primary,
          secondary: accent != null ? d.primary : null,
          background: Color.lerp(bg, Colors.black, 0.35),
          surface: bg);
    }
  }

  final r = m['radius'];
  if (r != null && r is! num) throw 'radius is not a number';
  final radius = ((r as num?) ?? 12).toDouble();
  if (radius.isNaN) throw 'radius is not a number';

  String? font(Object? v) {
    if (v is! String) return null;
    final f = v.trim();
    if (!_fontName.hasMatch(f)) return null;
    if (allowedFonts != null) {
      if (!allowedFonts.contains(f.toLowerCase())) return null;
    }
    return f;
  }

  return AiVariant(
    name: name,
    light: light,
    dark: dark,
    headingFont: font(m['headingFont']),
    bodyFont: font(m['bodyFont']),
    radius: radius.clamp(0, 32).toDouble(),
  );
}

/// Parses, validates and builds contrast-checked themes from a model answer.
/// Public so you can test your own prompt or provider.
List<ReskinTheme> themesFromModelJson(String raw,
    {required String source,
    String? prompt,
    int? max,
    List<String>? allowedFonts}) {
  return parseAiVariants(raw, max: max, allowedFonts: allowedFonts)
      .map((v) => v.toTheme(source: source, prompt: prompt))
      .toList();
}

/// An HTTP answer that was not 2xx. [statusCode] says why (401/403 key,
/// 429 rate limit, 5xx server).
class ReskinProviderException implements Exception {
  const ReskinProviderException(this.provider, this.statusCode, this.body);

  final String provider;
  final int statusCode;
  final String body;

  /// A short reason for the panel badge.
  String get reason => switch (statusCode) {
        400 when body.contains('API_KEY_INVALID') => 'API key rejected (400)',
        400 => 'request rejected (400)',
        401 => 'API key rejected (401)',
        403 => 'access denied (403)',
        404 => 'model not found (404)',
        429 => 'rate limited (429)',
        >= 500 => 'server error ($statusCode)',
        _ => 'HTTP $statusCode',
      };

  @override
  String toString() {
    final b = body.length > 300 ? '${body.substring(0, 300)}…' : body;
    return '$provider $reason: $b';
  }
}

Future<http.Response> _withRetry(
    int retries, Future<http.Response> Function() send) async {
  var res = await send();
  for (var i = 0;
      i < retries && const <int>{429, 500, 503}.contains(res.statusCode);
      i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    res = await send();
  }
  return res;
}

Future<ReskinPrompt> _withImageSeed(ReskinPrompt prompt) async {
  if (prompt.image == null) return prompt;
  final cs = await ColorScheme.fromImageProvider(provider: prompt.image!);
  return ReskinPrompt(
      text: prompt.text ?? 'a brand with this logo color',
      seed: cs.primary,
      count: prompt.count);
}

/// Uses your own Gemini API key (Google AI Studio). Debug tool: the key lives
/// in your app process, so pass it with `--dart-define` on a debug run and
/// never commit it or build a release with it.
class GeminiThemeProvider extends ReskinThemeProvider {
  GeminiThemeProvider({
    required this.apiKey,
    this.model = 'gemini-flash-lite-latest',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    this.headers = const <String, String>{},
    this.fonts,
    this.timeout = const Duration(seconds: 20),
    this.temperature = 0.8,
    this.thinkingBudget = 512,
    this.retries = 1,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;

  /// Default `gemini-flash-lite-latest`: an alias Google keeps pointing at a
  /// current Flash-Lite model. Pinned ids get retired: on 2026-11-08 a new
  /// AI Studio key got 404 "no longer available to new users" for
  /// `gemini-2.5-flash`. Use `gemini-flash-latest` for richer palettes
  /// (slower, and busier on free tiers).
  final String model;

  /// The API root; requests go to `$baseUrl/models/$model:generateContent`.
  /// Point it at your own proxy if you keep keys on a server.
  final String baseUrl;

  /// Extra headers (for a proxy). The key is sent as `x-goog-api-key` when
  /// [apiKey] is not empty.
  final Map<String, String> headers;

  /// Font families the model may choose from (the ones your app bundles or
  /// resolves). Null lets it pick any Google Font.
  final List<String>? fonts;
  final Duration timeout;
  final double temperature;

  /// Thinking tokens for Gemini 2.5 Flash models (`thinkingConfig`). Measured
  /// on gemini-2.5-flash: the model's default took 10–16 s per call, 512 about
  /// 5 s with similar palettes, 0 about 3–5 s with weaker dark palettes.
  /// Null sends nothing (the model's default). Only sent for Flash models.
  final int? thinkingBudget;

  /// Extra attempts after a 429 / 500 / 503 answer (free tiers often say
  /// "high demand"), 1.5 s apart. Timeouts are not retried.
  final int retries;
  final http.Client _client;

  @override
  String get name => 'gemini';

  @override
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    final p = await _withImageSeed(prompt);
    final uri = Uri.parse('$baseUrl/models/$model:generateContent');
    final res = await _withRetry(
        retries,
        () => _client
            .post(
              uri,
              headers: <String, String>{
                'content-type': 'application/json',
                if (apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
                ...headers,
              },
              body: jsonEncode(<String, Object?>{
                'systemInstruction': <String, Object?>{
                  'parts': <Object>[
                    <String, String>{'text': kReskinSystemPrompt}
                  ]
                },
                'contents': <Object>[
                  <String, Object?>{
                    'role': 'user',
                    'parts': <Object>[
                      <String, String>{
                        'text': reskinUserMessage(p, fonts: fonts)
                      }
                    ],
                  }
                ],
                'generationConfig': <String, Object?>{
                  'responseMimeType': 'application/json',
                  'responseSchema': kReskinGeminiSchema,
                  'temperature': temperature,
                  if (thinkingBudget != null && model.contains('flash'))
                    'thinkingConfig': <String, Object>{
                      'thinkingBudget': thinkingBudget!
                    },
                },
              }),
            )
            .timeout(timeout));
    if (res.statusCode >= 400) {
      throw ReskinProviderException('Gemini', res.statusCode, res.body);
    }
    final text = _geminiText(res.body);
    return themesFromModelJson(text,
        source: name, prompt: p.text, max: p.count, allowedFonts: fonts);
  }
}

String _geminiText(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final candidates = j['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final block =
          (j['promptFeedback'] as Map<String, dynamic>?)?['blockReason'];
      throw ReskinResponseException(block != null
          ? 'Gemini blocked the prompt ($block).'
          : 'Gemini returned no candidates.');
    }
    final c = candidates.first as Map<String, dynamic>;
    final parts =
        (c['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
    if (parts == null) {
      throw ReskinResponseException(
          'Gemini returned no content (${c['finishReason'] ?? 'unknown'}).');
    }
    return parts
        .map((e) => (e as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
  } on ReskinResponseException {
    rethrow;
  } catch (e) {
    throw ReskinResponseException(
        'Unexpected Gemini response shape.', <String>['$e']);
  }
}

/// Uses your own OpenAI API key (Chat Completions with structured outputs).
/// Works with any OpenAI-compatible server through [baseUrl]; set
/// [structuredOutputs] to false for servers that only know JSON mode.
class OpenAIThemeProvider extends ReskinThemeProvider {
  OpenAIThemeProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1',
    this.headers = const <String, String>{},
    this.fonts,
    this.timeout = const Duration(seconds: 20),
    this.structuredOutputs = true,
    this.retries = 1,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;

  /// Point this at any OpenAI-compatible server.
  final String baseUrl;
  final Map<String, String> headers;
  final List<String>? fonts;
  final Duration timeout;

  /// `json_schema` (strict) when true, plain `json_object` mode when false.
  final bool structuredOutputs;

  /// Extra attempts after a 429 / 500 / 503 answer, 1.5 s apart.
  final int retries;
  final http.Client _client;

  @override
  String get name => 'openai';

  @override
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    final p = await _withImageSeed(prompt);
    final uri = Uri.parse('$baseUrl/chat/completions');
    final res = await _withRetry(
        retries,
        () => _client
            .post(
              uri,
              headers: <String, String>{
                'content-type': 'application/json',
                if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
                ...headers,
              },
              body: jsonEncode(<String, Object?>{
                'model': model,
                'response_format': structuredOutputs
                    ? <String, Object?>{
                        'type': 'json_schema',
                        'json_schema': <String, Object?>{
                          'name': 'reskin_themes',
                          'strict': true,
                          'schema': kReskinJsonSchema,
                        },
                      }
                    : <String, String>{'type': 'json_object'},
                'messages': <Object>[
                  <String, String>{
                    'role': 'system',
                    'content': kReskinSystemPrompt
                  },
                  <String, String>{
                    'role': 'user',
                    'content': reskinUserMessage(p, fonts: fonts)
                  },
                ],
              }),
            )
            .timeout(timeout));
    if (res.statusCode >= 400) {
      throw ReskinProviderException('OpenAI', res.statusCode, res.body);
    }
    final String content;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final choice =
          (body['choices'] as List<dynamic>).first as Map<String, dynamic>;
      final msg = choice['message'] as Map<String, dynamic>;
      final refusal = msg['refusal'];
      if (refusal is String && refusal.isNotEmpty) {
        throw ReskinResponseException('OpenAI refused: $refusal');
      }
      content = msg['content'] as String;
    } on ReskinResponseException {
      rethrow;
    } catch (e) {
      throw ReskinResponseException(
          'Unexpected OpenAI response shape.', <String>['$e']);
    }
    return themesFromModelJson(content,
        source: name, prompt: p.text, max: p.count, allowedFonts: fonts);
  }
}

/// Picks a provider from keys: Gemini first, then OpenAI, else offline.
abstract final class ReskinProviders {
  /// Gemini when [geminiKey] is set, else OpenAI when [openAIKey] is set,
  /// else [OfflineThemeProvider]. Outside debug builds this always returns
  /// the offline provider, so a key can never be used from a release app.
  static ReskinThemeProvider fromKeys({
    String? geminiKey,
    String? openAIKey,
    String? geminiModel,
    String? openAIModel,
    String? geminiBaseUrl,
    String? openAIBaseUrl,
    List<String>? fonts,
    Duration timeout = const Duration(seconds: 20),
    bool allowOutsideDebug = false,
  }) {
    if (!kDebugMode && !allowOutsideDebug) return const OfflineThemeProvider();
    if (geminiKey != null && geminiKey.isNotEmpty) {
      return GeminiThemeProvider(
        apiKey: geminiKey,
        model: geminiModel ?? 'gemini-flash-lite-latest',
        baseUrl:
            geminiBaseUrl ?? 'https://generativelanguage.googleapis.com/v1beta',
        fonts: fonts,
        timeout: timeout,
      );
    }
    if (openAIKey != null && openAIKey.isNotEmpty) {
      return OpenAIThemeProvider(
        apiKey: openAIKey,
        model: openAIModel ?? 'gpt-4o-mini',
        baseUrl: openAIBaseUrl ?? 'https://api.openai.com/v1',
        fonts: fonts,
        timeout: timeout,
      );
    }
    return const OfflineThemeProvider();
  }

  /// Reads `--dart-define` values: `RESKIN_GEMINI_KEY` (or
  /// `RESKIN_OPENAI_KEY`), and optionally `RESKIN_GEMINI_MODEL`,
  /// `RESKIN_OPENAI_MODEL`, `RESKIN_GEMINI_BASE_URL`,
  /// `RESKIN_OPENAI_BASE_URL`. Debug runs only.
  static ReskinThemeProvider fromEnvironment({List<String>? fonts}) {
    String? env(String v) => v.isEmpty ? null : v;
    return fromKeys(
      geminiKey: env(const String.fromEnvironment('RESKIN_GEMINI_KEY')),
      openAIKey: env(const String.fromEnvironment('RESKIN_OPENAI_KEY')),
      geminiModel: env(const String.fromEnvironment('RESKIN_GEMINI_MODEL')),
      openAIModel: env(const String.fromEnvironment('RESKIN_OPENAI_MODEL')),
      geminiBaseUrl:
          env(const String.fromEnvironment('RESKIN_GEMINI_BASE_URL')),
      openAIBaseUrl:
          env(const String.fromEnvironment('RESKIN_OPENAI_BASE_URL')),
      fonts: fonts,
    );
  }
}

/// A short, human reason for a provider failure (for the panel badge).
String reskinFailureReason(Object e) {
  if (e is TimeoutException) {
    return 'timed out${e.duration != null ? ' after ${e.duration!.inSeconds}s' : ''}';
  }
  if (e is ReskinProviderException) return e.reason;
  if (e is ReskinResponseException) return 'bad answer: ${e.message}';
  if (e is http.ClientException) return 'network error';
  if (e is FormatException) return 'bad answer: ${e.message}';
  final s = '$e';
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return 'no network';
  }
  return s.length > 80 ? '${s.substring(0, 80)}…' : s;
}
