// Live check against the real Gemini (or OpenAI) API. Not part of the
// normal test run: it is skipped unless a key or endpoint is in the
// environment. Nothing here stores a key.
//
//   RESKIN_GEMINI_KEY=... flutter test tool/live_test.dart
//   RESKIN_OPENAI_KEY=... flutter test tool/live_test.dart
//
// Optional: RESKIN_GEMINI_BASE_URL / RESKIN_OPENAI_BASE_URL (a proxy),
// RESKIN_LIVE_HEADERS (JSON object of extra headers), RESKIN_LIVE_MODEL,
// RESKIN_LIVE_PROMPTS (JSON list), RESKIN_LIVE_OUT (write results as JSON).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reskin/reskin.dart';

const List<String> _defaultPrompts = <String>[
  'Ramadan night, gold on navy',
  'morning coffee colors',
  'ألوان قهوة الصبح',
  'calm medical app for students',
  'cyberpunk neon',
];

/// The fonts the example app bundles.
const List<String> _fonts = <String>[
  'Inter',
  'Manrope',
  'Cormorant Garamond',
  'El Messiri',
  'JetBrains Mono',
  'DejaVu Serif',
];

class _Recorder extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _inner.send(request);
    final bytes = await res.stream.toBytes();
    lastBody = utf8.decode(bytes);
    return http.StreamedResponse(Stream<List<int>>.value(bytes), res.statusCode,
        headers: res.headers, request: request);
  }
}

String _hex(Color? c) => c == null ? '-' : colorHex(c);

void main() {
  HttpOverrides.global = null;
  final env = Platform.environment;
  final geminiKey = env['RESKIN_GEMINI_KEY'] ?? '';
  final geminiBase = env['RESKIN_GEMINI_BASE_URL'];
  final openAIKey = env['RESKIN_OPENAI_KEY'] ?? '';
  final openAIBase = env['RESKIN_OPENAI_BASE_URL'];
  final useGemini = geminiKey.isNotEmpty || geminiBase != null;
  final useOpenAI = !useGemini && (openAIKey.isNotEmpty || openAIBase != null);
  final headers = env['RESKIN_LIVE_HEADERS'] == null
      ? const <String, String>{}
      : (jsonDecode(env['RESKIN_LIVE_HEADERS']!) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, '$v'));
  final prompts = env['RESKIN_LIVE_PROMPTS'] == null
      ? _defaultPrompts
      : (jsonDecode(env['RESKIN_LIVE_PROMPTS']!) as List<dynamic>)
          .cast<String>();

  test('live prompts', () async {
    final rec = _Recorder();
    final ReskinThemeProvider provider = useGemini
        ? GeminiThemeProvider(
            apiKey: geminiKey,
            model: env['RESKIN_LIVE_MODEL'] ?? 'gemini-flash-lite-latest',
            baseUrl: geminiBase ??
                'https://generativelanguage.googleapis.com/v1beta',
            headers: headers,
            fonts: _fonts,
            timeout: const Duration(seconds: 60),
            client: rec)
        : OpenAIThemeProvider(
            apiKey: openAIKey,
            model: env['RESKIN_LIVE_MODEL'] ?? 'gpt-4o-mini',
            baseUrl: openAIBase ?? 'https://api.openai.com/v1',
            headers: headers,
            fonts: _fonts,
            timeout: const Duration(seconds: 60),
            client: rec);
    final results = <Map<String, Object?>>[];
    for (final prompt in prompts) {
      final sw = Stopwatch()..start();
      final entry = <String, Object?>{'prompt': prompt};
      try {
        final themes = await provider.generate(ReskinPrompt.text(prompt));
        entry['ms'] = sw.elapsedMilliseconds;
        // What the model said, validated, and what reskin had to fix.
        final raw = _modelText(rec.lastBody!, provider.name);
        entry['raw'] = jsonDecode(raw);
        final parsed = parseAiVariants(raw, allowedFonts: _fonts);
        entry['variants'] = <Object>[
          for (var i = 0; i < themes.length; i++)
            <String, Object?>{
              'name': themes[i].name,
              'light': parsed[i].light.toString(),
              'dark': parsed[i].dark?.toString(),
              'headingFont': themes[i].headingFont,
              'bodyFont': themes[i].bodyFont,
              'radius': themes[i].radius,
              'contrastFixesLight': ensureReadable(
                      schemeFromPalette(parsed[i].light, Brightness.light))
                  .$2
                  .adjustedCount,
              'contrastFixesDark': parsed[i].dark == null
                  ? null
                  : ensureReadable(
                          schemeFromPalette(parsed[i].dark!, Brightness.dark))
                      .$2
                      .adjustedCount,
              'final': <String, String>{
                'light.primary': _hex(themes[i].light.primary),
                'light.onPrimary': _hex(themes[i].light.onPrimary),
                'light.surface': _hex(themes[i].light.surface),
                'dark.primary': _hex(themes[i].dark.primary),
                'dark.surface': _hex(themes[i].dark.surface),
              },
              'export': exportThemeDart(themes[i]),
            }
        ];
        // ignore: avoid_print
        print('OK  $prompt (${entry['ms']} ms)');
        for (final t in themes) {
          // ignore: avoid_print
          print('    ${t.name}: light ${_hex(t.light.primary)} on '
              '${_hex(t.light.surface)}, dark ${_hex(t.dark.primary)} on '
              '${_hex(t.dark.surface)}, ${t.headingFont}/${t.bodyFont}, '
              'r${t.radius}');
        }
      } catch (e) {
        entry['ms'] = sw.elapsedMilliseconds;
        entry['error'] = '$e';
        // ignore: avoid_print
        print('ERR $prompt: $e');
      }
      results.add(entry);
    }
    final out = env['RESKIN_LIVE_OUT'];
    if (out != null) {
      File(out).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'provider': provider.name,
        'model': env['RESKIN_LIVE_MODEL'] ??
            (useGemini ? 'gemini-flash-lite-latest' : 'gpt-4o-mini'),
        'at': DateTime.now().toUtc().toIso8601String(),
        'results': results,
      }));
    }
    expect(results.where((r) => r['error'] == null), isNotEmpty);
  },
      skip: useGemini || useOpenAI
          ? false
          : 'set RESKIN_GEMINI_KEY or RESKIN_OPENAI_KEY to run',
      timeout: const Timeout(Duration(minutes: 6)));
}

String _modelText(String body, String provider) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  if (provider == 'gemini') {
    final c = (j['candidates'] as List<dynamic>).first as Map<String, dynamic>;
    return ((c['content'] as Map<String, dynamic>)['parts'] as List<dynamic>)
        .map((p) => (p as Map<String, dynamic>)['text'] ?? '')
        .join();
  }
  final c = (j['choices'] as List<dynamic>).first as Map<String, dynamic>;
  return (c['message'] as Map<String, dynamic>)['content'] as String;
}
