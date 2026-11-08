import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reskin/reskin.dart';

/// A real answer shape from Gemini (trimmed to two variants).
const String _good = '''
{"variants":[
 {"name":"Espresso Blend",
  "light":{"primary":"#6F4E37","secondary":"#A0522D","background":"#F5F5DC","surface":"#FFF8DC"},
  "dark":{"primary":"#D2B48C","secondary":"#EEDDCC","background":"#362A20","surface":"#4A3B30"},
  "headingFont":"Cormorant Garamond","bodyFont":"Inter","radius":12},
 {"name":"قهوة الصباح",
  "light":{"primary":"#4A2C2A","secondary":"#B07D62","background":"#F8F0E3","surface":"#FFFCEF"},
  "dark":{"primary":"#E0C8A8","secondary":"#D4A462","background":"#231715","surface":"#372725"},
  "headingFont":"El Messiri","bodyFont":"Inter","radius":40}
]}
''';

http.Response _gemini(String text) => http.Response(
        jsonEncode(<String, Object>{
          'candidates': <Object>[
            <String, Object>{
              'content': <String, Object>{
                'parts': <Object>[
                  <String, String>{'text': text}
                ]
              },
              'finishReason': 'STOP',
            }
          ]
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8'
        });

void main() {
  group('parseAiVariants (strict validation)', () {
    test('reads light + dark palettes, fonts and radius', () {
      final v = parseAiVariants(_good);
      expect(v, hasLength(2));
      expect(v.first.name, 'Espresso Blend');
      expect(v.first.light.primary, const Color(0xFF6F4E37));
      expect(v.first.light.surface, const Color(0xFFFFF8DC));
      expect(v.first.dark!.background, const Color(0xFF362A20));
      expect(v.first.headingFont, 'Cormorant Garamond');
      expect(v[1].name, 'قهوة الصباح');
      expect(v[1].radius, 32, reason: 'radius is clamped to 0..32');
    });

    test('rejects bad variants and says why, keeps the good ones', () {
      const raw = '''
{"variants":[
 {"name":"","light":{"primary":"#112233"}},
 {"name":"No light"},
 {"name":"Bad hex","light":{"primary":"navy"}},
 {"name":"Bad secondary","light":{"primary":"#112233","secondary":"gold"}},
 {"name":"Bad radius","light":{"primary":"#112233"},"radius":"big"},
 "just a string",
 {"name":"Fine","light":{"primary":"#112233"}}
]}''';
      final v = parseAiVariants(raw);
      expect(v.map((e) => e.name), <String>['Fine']);
      expect(v.single.dark, isNull);
      expect(v.single.radius, 12);
    });

    test('throws ReskinResponseException with reasons when nothing is usable',
        () {
      expect(
          () => parseAiVariants(
              '{"variants":[{"name":"x","light":{"primary":"red"}}]}'),
          throwsA(isA<ReskinResponseException>().having(
              (e) => e.problems.single, 'problem', contains('light.primary'))));
      expect(() => parseAiVariants('not json at all'),
          throwsA(isA<ReskinResponseException>()));
      expect(
          () => parseAiVariants(''), throwsA(isA<ReskinResponseException>()));
      expect(() => parseAiVariants('{"themes":[]}'),
          throwsA(isA<ReskinResponseException>()));
      expect(() => parseAiVariants('{"variants":[]}'), throwsFormatException);
    });

    test('accepts a ```json fence and a bare list, and caps to max', () {
      final fenced = parseAiVariants('```json\n$_good\n```', max: 1);
      expect(fenced, hasLength(1));
      final list =
          jsonEncode((jsonDecode(_good) as Map<String, dynamic>)['variants']);
      expect(parseAiVariants(list), hasLength(2));
    });

    test('drops implausible fonts and fonts outside the allowed list', () {
      const raw = '''
{"variants":[{"name":"A","light":{"primary":"#112233"},
 "headingFont":"Comic; drop table","bodyFont":"Roboto"}]}''';
      final free = parseAiVariants(raw).single;
      expect(free.headingFont, isNull);
      expect(free.bodyFont, 'Roboto');
      final only = parseAiVariants(raw, allowedFonts: <String>['Inter']).single;
      expect(only.bodyFont, isNull);
    });

    test('built themes keep the model colors and pass WCAG AA', () {
      final t = themesFromModelJson(_good, source: 'gemini', prompt: 'p');
      expect(t.first.light.primary, const Color(0xFF6F4E37));
      expect(t.first.light.secondary, const Color(0xFFA0522D));
      expect(t.first.light.surface, const Color(0xFFF5F5DC));
      expect(t.first.light.surfaceContainerLow, const Color(0xFFFFF8DC));
      expect(t.first.dark.surface, const Color(0xFF362A20));
      expect(t.first.source, 'gemini');
      expect(t.first.prompt, 'p');
      for (final theme in t) {
        expect(ensureReadable(theme.light).$2.adjustedCount, 0);
        expect(ensureReadable(theme.dark).$2.adjustedCount, 0);
      }
    });

    test('unreadable model colors are fixed, not trusted', () {
      // Neon cyan button with a pale text color on a white page.
      const raw = '''
{"variants":[{"name":"Neon","light":{"primary":"#00FFFF","secondary":"#FF00FF",
"background":"#FFFFFF","surface":"#FAFAFA"},
"dark":{"primary":"#00FFFF","secondary":"#FF00FF","background":"#0A0A0A","surface":"#141414"}}]}''';
      final t = themesFromModelJson(raw, source: 'gemini').single;
      expect(contrastRatio(t.light.onPrimary, t.light.primary),
          greaterThanOrEqualTo(4.5));
      // Cyan as a text/icon color on white is darkened (same hue) to 3:1.
      expect(contrastRatio(t.light.primary, t.light.surface),
          greaterThanOrEqualTo(3));
      expect(HSLColor.fromColor(t.light.primary).hue, closeTo(180, 1));
      expect(t.dark.primary, const Color(0xFF00FFFF), reason: 'fine on black');
      expect(contrastRatio(t.light.onSurface, t.light.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(t.dark.onSurface, t.dark.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('legacy flat answers (seed/accent/background) still work', () {
      final t = themesFromModelJson(
          '{"variants":[{"name":"Old","seed":"#1B2A4A","accent":"#D4AF37","background":"#101828"}]}',
          source: 'x');
      expect(t.single.light.primary, const Color(0xFF1B2A4A));
      expect(t.single.dark.surfaceContainerLow, const Color(0xFF101828));
    });
  });

  group('providers', () {
    test('Gemini sends schema + fonts, parses UTF-8 Arabic names', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return _gemini(_good);
      });
      final p = GeminiThemeProvider(
          apiKey: 'k',
          client: client,
          fonts: const <String>['Inter', 'El Messiri', 'Cormorant Garamond']);
      final v = await p.generate(const ReskinPrompt.text('ألوان قهوة الصبح'));
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      final config = body['generationConfig'] as Map<String, dynamic>;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseSchema'], isA<Map<String, dynamic>>());
      final user = jsonEncode(body['contents']);
      expect(user, contains('ألوان قهوة الصبح'));
      expect(user, contains('Arabic script is supported by: El Messiri'));
      expect(v.map((t) => t.name), contains('قهوة الصباح'));
    });

    test('Gemini custom baseUrl + headers, no key header when key is empty',
        () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return _gemini(_good);
      });
      await GeminiThemeProvider(
        apiKey: '',
        baseUrl: 'https://proxy.example/gemini',
        headers: const <String, String>{'authorization': 'Bearer t'},
        model: 'gemini-x',
        client: client,
      ).generate(const ReskinPrompt.text('ocean'));
      expect(seen.url.toString(),
          'https://proxy.example/gemini/models/gemini-x:generateContent');
      expect(seen.headers.containsKey('x-goog-api-key'), isFalse);
      expect(seen.headers['authorization'], 'Bearer t');
    });

    test('Gemini HTTP errors become ReskinProviderException with a reason',
        () async {
      final p = GeminiThemeProvider(
          apiKey: 'bad',
          client: MockClient((_) async => http.Response('{"error":{}}', 403)));
      await expectLater(
          p.generate(const ReskinPrompt.text('ocean')),
          throwsA(isA<ReskinProviderException>()
              .having((e) => e.reason, 'reason', 'access denied (403)')));
    });

    test('Gemini blocked / empty answers are response errors', () async {
      final blocked = GeminiThemeProvider(
          apiKey: 'k',
          client: MockClient((_) async => http.Response(
              '{"promptFeedback":{"blockReason":"SAFETY"}}', 200)));
      await expectLater(blocked.generate(const ReskinPrompt.text('x')),
          throwsA(isA<ReskinResponseException>()));
    });

    test('OpenAI refusal is a response error', () async {
      final p = OpenAIThemeProvider(
          apiKey: 'k',
          client: MockClient((_) async => http.Response(
              '{"choices":[{"message":{"content":null,"refusal":"no"}}]}',
              200)));
      await expectLater(p.generate(const ReskinPrompt.text('x')),
          throwsA(isA<ReskinResponseException>()));
    });

    test('fromKeys prefers Gemini, then OpenAI, else offline', () {
      expect(ReskinProviders.fromKeys(geminiKey: 'g', openAIKey: 'o').name,
          'gemini');
      expect(ReskinProviders.fromKeys(openAIKey: 'o').name, 'openai');
      expect(ReskinProviders.fromKeys(geminiKey: '').name, 'offline');
      expect(ReskinProviders.fromEnvironment().name, 'offline',
          reason: 'no --dart-define in tests');
    });
  });

  group('controller fallback', () {
    test('AI answer is used first when it works', () async {
      final c = ReskinController(
          provider: GeminiThemeProvider(
              apiKey: 'k', client: MockClient((_) async => _gemini(_good))));
      final v = await c.generateFromText('morning coffee colors');
      expect(v.first.source, 'gemini');
      expect(c.source, 'gemini');
      expect(c.usedFallback, isFalse);
      expect(c.fallbackReason, isNull);
    });

    test('invalid JSON falls back offline with a reason', () async {
      final c = ReskinController(
          provider: GeminiThemeProvider(
              apiKey: 'k',
              client: MockClient((_) async => _gemini('{"variants":"oops"}'))));
      final v = await c.generateFromText('gold on navy');
      expect(v, hasLength(4));
      expect(v.first.source, 'offline');
      expect(c.usedFallback, isTrue);
      expect(c.source, 'offline');
      expect(c.fallbackReason, startsWith('bad answer'));
    });

    test('a slow provider times out and falls back', () async {
      final c = ReskinController(
        provider: GeminiThemeProvider(
            apiKey: 'k',
            timeout: const Duration(seconds: 30),
            client: MockClient(
                (_) => Completer<http.Response>().future)), // never answers
        timeout: const Duration(milliseconds: 50),
      );
      final v = await c.generateFromText('ocean');
      expect(v.first.source, 'offline');
      expect(c.fallbackReason, contains('timed out'));
    });

    test('a network error falls back and the next success clears it', () async {
      var fail = true;
      final c = ReskinController(
          provider: GeminiThemeProvider(
              apiKey: 'k',
              client: MockClient((req) async {
                if (fail) throw http.ClientException('offline', req.url);
                return _gemini(_good);
              })));
      await c.generateFromText('ocean');
      expect(c.fallbackReason, 'network error');
      fail = false;
      await c.generateFromText('ocean');
      expect(c.usedFallback, isFalse);
      expect(c.source, 'gemini');
    });

    test('reskinFailureReason is short and human', () {
      expect(
          reskinFailureReason(
              TimeoutException('t', const Duration(seconds: 20))),
          'timed out after 20s');
      expect(
          reskinFailureReason(const ReskinProviderException('Gemini', 429, '')),
          'rate limited (429)');
    });
  });
}
