import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'contrast.dart';
import 'generator.dart';
import 'spec.dart';

/// The instruction every AI provider sends. The model only picks colors,
/// fonts and radius; reskin builds full schemes and checks contrast itself.
const String kReskinSystemPrompt = '''
You design Flutter Material 3 themes. Reply with JSON only, no prose:
{"variants":[{"name":"short name","seed":"#RRGGBB","accent":"#RRGGBB or null",
"background":"#RRGGBB or null (dark-mode surface hint)",
"headingFont":"Google Font family or null","bodyFont":"Google Font family or null",
"radius":0-32}]}
Return exactly the number of variants asked for. Make them clearly different.
''';

/// Shared parsing for model answers. Public so you can test your own prompt.
List<ReskinTheme> themesFromModelJson(String raw,
    {required String source, String? prompt}) {
  var text = raw.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  final decoded = jsonDecode(text);
  final list = decoded is Map<String, dynamic>
      ? decoded['variants'] as List<dynamic>? ?? const <dynamic>[]
      : decoded as List<dynamic>;
  final out = <ReskinTheme>[];
  for (final item in list.cast<Map<String, dynamic>>()) {
    final seed = parseHexColor(item['seed'] as String?);
    if (seed == null) continue;
    final intent = PromptIntent(
      seed: seed,
      title: (item['name'] as String?)?.trim().isNotEmpty == true
          ? item['name'] as String
          : 'AI',
      accent: parseHexColor(item['accent'] as String?),
      background: parseHexColor(item['background'] as String?),
      headingFont: item['headingFont'] as String?,
      bodyFont: item['bodyFont'] as String?,
      radius: ((item['radius'] as num?) ?? 12).toDouble().clamp(0, 32),
    );
    final t = buildTheme(intent, DynamicSchemeVariant.fidelity,
        name: intent.title, source: source);
    final (light, _) = ensureReadable(t.light);
    final (dark, _) = ensureReadable(t.dark);
    out.add(t.copyWith(light: light, dark: dark, prompt: prompt));
  }
  if (out.isEmpty) {
    throw const FormatException('The model returned no usable variants.');
  }
  return out;
}

/// `#RRGGBB`, `RRGGBB`, `#AARRGGBB` or `0xAARRGGBB`. Null if not a color.
Color? parseHexColor(String? s) {
  if (s == null) return null;
  var h = s.trim().toUpperCase().replaceFirst('#', '').replaceFirst('0X', '');
  if (!RegExp(r'^[0-9A-F]{6}([0-9A-F]{2})?$').hasMatch(h)) return null;
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

String _userMessage(ReskinPrompt p) {
  final b = StringBuffer('Give ${p.count} theme variants for: ');
  b.write(p.text ?? 'a brand');
  if (p.seed != null) b.write(' (brand color ${colorHex(p.seed!)})');
  return b.toString();
}

/// Uses your own Gemini API key (Google AI Studio). Debug tool: the key lives
/// in your app process, so read it from `--dart-define`, never commit it.
class GeminiThemeProvider extends ReskinThemeProvider {
  GeminiThemeProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
    this.fallback = const OfflineThemeProvider(),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  /// Used for image prompts (the seed is read from the image locally first).
  final ReskinThemeProvider fallback;

  @override
  String get name => 'gemini';

  @override
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    var p = prompt;
    if (prompt.image != null) {
      final cs = await ColorScheme.fromImageProvider(provider: prompt.image!);
      p = ReskinPrompt(
          text: prompt.text ?? 'this logo',
          seed: cs.primary,
          count: prompt.count);
    }
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final res = await _client.post(
      uri,
      headers: <String, String>{
        'content-type': 'application/json',
        'x-goog-api-key': apiKey,
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
              <String, String>{'text': _userMessage(p)}
            ],
          }
        ],
        'generationConfig': <String, Object?>{
          'responseMimeType': 'application/json',
          'temperature': 0.9,
        },
      }),
    );
    if (res.statusCode >= 400) {
      throw http.ClientException('Gemini ${res.statusCode}: ${res.body}', uri);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>;
    final parts = ((candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>)['parts'] as List<dynamic>;
    final text =
        parts.map((e) => (e as Map<String, dynamic>)['text'] ?? '').join();
    return themesFromModelJson(text, source: 'gemini', prompt: p.text);
  }
}

/// Uses your own OpenAI API key (Chat Completions, JSON mode).
class OpenAIThemeProvider extends ReskinThemeProvider {
  OpenAIThemeProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;

  /// Point this at any OpenAI-compatible server.
  final String baseUrl;
  final http.Client _client;

  @override
  String get name => 'openai';

  @override
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    var p = prompt;
    if (prompt.image != null) {
      final cs = await ColorScheme.fromImageProvider(provider: prompt.image!);
      p = ReskinPrompt(
          text: prompt.text ?? 'this logo',
          seed: cs.primary,
          count: prompt.count);
    }
    final uri = Uri.parse('$baseUrl/chat/completions');
    final res = await _client.post(
      uri,
      headers: <String, String>{
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(<String, Object?>{
        'model': model,
        'response_format': <String, String>{'type': 'json_object'},
        'messages': <Object>[
          <String, String>{'role': 'system', 'content': kReskinSystemPrompt},
          <String, String>{'role': 'user', 'content': _userMessage(p)},
        ],
      }),
    );
    if (res.statusCode >= 400) {
      throw http.ClientException('OpenAI ${res.statusCode}: ${res.body}', uri);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choice =
        (body['choices'] as List<dynamic>).first as Map<String, dynamic>;
    final content =
        (choice['message'] as Map<String, dynamic>)['content'] as String;
    return themesFromModelJson(content, source: 'openai', prompt: p.text);
  }
}
