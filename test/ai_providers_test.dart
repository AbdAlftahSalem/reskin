import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reskin/reskin.dart';

const _answer = '''
{"variants":[
 {"name":"Night Souq","seed":"#1B2A4A","accent":"#D4AF37","background":"#101828","headingFont":"El Messiri","bodyFont":null,"radius":18},
 {"name":"Sand","seed":"C8A165","radius":8},
 {"name":"broken","seed":"not a color"}
]}
''';

void main() {
  test('parseHexColor handles common forms', () {
    expect(parseHexColor('#1B2A4A'), const Color(0xFF1B2A4A));
    expect(parseHexColor('1b2a4a'), const Color(0xFF1B2A4A));
    expect(parseHexColor('0x801B2A4A'), const Color(0x801B2A4A));
    expect(parseHexColor('navy'), isNull);
    expect(parseHexColor(null), isNull);
  });

  test('themesFromModelJson skips bad items, fences ok, contrast enforced', () {
    final t = themesFromModelJson('```json\n$_answer\n```', source: 'test');
    expect(t.map((e) => e.name), <String>['Night Souq', 'Sand']);
    expect(t.first.headingFont, 'El Messiri');
    expect(t.first.radius, 18);
    for (final theme in t) {
      expect(ensureReadable(theme.light).$2.adjustedCount, 0);
      expect(ensureReadable(theme.dark).$2.adjustedCount, 0);
    }
    expect(() => themesFromModelJson('{"variants":[]}', source: 'x'),
        throwsFormatException);
  });

  test('Gemini provider sends key in header and parses the answer', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode(<String, Object>{
            'candidates': <Object>[
              <String, Object>{
                'content': <String, Object>{
                  'parts': <Object>[
                    <String, String>{'text': _answer}
                  ]
                }
              }
            ]
          }),
          200);
    });
    final p = GeminiThemeProvider(apiKey: 'k-123', client: client);
    final v = await p.generate(const ReskinPrompt.text('ramadan', count: 2));
    expect(seen.headers['x-goog-api-key'], 'k-123');
    expect(seen.url.path, contains('gemini-flash-lite-latest:generateContent'));
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(jsonEncode(body['contents']), contains('ramadan'));
    expect(v.first.source, 'gemini');
    expect(v, hasLength(2));
  });

  test('OpenAI provider uses bearer auth and strict structured outputs',
      () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode(<String, Object>{
            'choices': <Object>[
              <String, Object>{
                'message': <String, String>{'content': _answer}
              }
            ]
          }),
          200);
    });
    final p = OpenAIThemeProvider(apiKey: 'sk-test', client: client);
    final v = await p.generate(const ReskinPrompt.seed(Color(0xFF00897B)));
    expect(seen.headers['authorization'], 'Bearer sk-test');
    final format = (jsonDecode(seen.body)
        as Map<String, dynamic>)['response_format'] as Map<String, dynamic>;
    expect(format['type'], 'json_schema');
    expect((format['json_schema'] as Map<String, dynamic>)['strict'], isTrue);
    final jsonMode = OpenAIThemeProvider(
        apiKey: 'sk-test', client: client, structuredOutputs: false);
    await jsonMode.generate(const ReskinPrompt.text('ocean'));
    expect((jsonDecode(seen.body) as Map<String, dynamic>)['response_format'],
        <String, String>{'type': 'json_object'});
    expect(v.first.source, 'openai');
  });

  test('controller falls back to offline when a provider fails', () async {
    final client = MockClient((_) async => http.Response('quota', 429));
    final c = ReskinController(
        provider: OpenAIThemeProvider(apiKey: 'x', client: client));
    final v = await c.generateFromText('ocean');
    expect(v, isNotEmpty);
    expect(v.first.source, 'offline');
    expect(c.error, contains('429'));
    expect(c.current, isNotNull);
  });
}
