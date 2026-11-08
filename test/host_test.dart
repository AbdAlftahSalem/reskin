import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reskin/reskin.dart';

Color? _seenPrimary;
Brightness? _seenBrightness;

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    _seenPrimary = t.colorScheme.primary;
    _seenBrightness = t.brightness;
    return const Scaffold(body: Center(child: Text('app')));
  }
}

Widget _app(ReskinController c,
    {ValueChanged<String>? onExport, bool enabled = true}) {
  final light =
      ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple);
  final dark = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.deepPurple,
      brightness: Brightness.dark);
  return MaterialApp(
    theme: light,
    darkTheme: dark,
    builder: Reskin.builder(
      controller: c,
      theme: light,
      darkTheme: dark,
      enabled: enabled,
      onExport: onExport,
      registerServiceExtensions: false,
    ),
    home: const _Probe(),
  );
}

void main() {
  testWidgets('disabled builder returns the app untouched', (tester) async {
    await tester.pumpWidget(_app(ReskinController(), enabled: false));
    expect(find.byType(ReskinHost), findsNothing);
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('prompt in the panel restyles the running app', (tester) async {
    final c = ReskinController();
    await tester.pumpWidget(_app(c));
    await tester.pump();
    final before = _seenPrimary;

    await tester.tap(find.byKey(const Key('reskin-pill')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('reskin-prompt')), 'gold on navy');
    await tester.tap(find.byKey(const Key('reskin-generate')));
    await tester.pumpAndSettle();

    expect(c.variants, hasLength(4));
    expect(c.index, 0);
    expect(_seenPrimary, isNot(before));
    expect(_seenPrimary, c.current!.light.primary);

    // Second variant via the controller (the carousel calls the same method).
    c.select(1);
    await tester.pumpAndSettle();
    expect(_seenPrimary, c.variants[1].light.primary);

    // Dark toggle.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(_seenBrightness, Brightness.dark);
    expect(_seenPrimary, c.variants[1].dark.primary);

    // Back to the original.
    c.select(-1);
    c.setDark(false);
    await tester.pumpAndSettle();
    expect(_seenPrimary, before);
  });

  testWidgets('export shows app_theme.dart, calls back and copies',
      (tester) async {
    String? exported;
    String? clipboard;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    final c = ReskinController();
    await tester.pumpWidget(_app(c, onExport: (s) => exported = s));
    await tester.pump();
    await c.generateFromText('forest');
    c.setPanelOpen(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reskin-export')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reskin-export-view')), findsOneWidget);
    expect(find.text('lib/app_theme.dart'), findsOneWidget);
    expect(exported, contains('class AppTheme'));
    await tester.tap(find.byKey(const Key('reskin-copy')));
    await tester.pumpAndSettle();
    expect(clipboard, exported);
    expect(find.text('Copied'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reskin-export-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reskin-export-view')), findsNothing);
  });

  testWidgets('panel shows an "offline" badge when the AI call fails',
      (tester) async {
    final c = ReskinController(
        provider: GeminiThemeProvider(
            apiKey: 'bad',
            client: MockClient((_) async => http.Response('denied', 401))));
    await tester.pumpWidget(_app(c));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reskin-pill')));
    await tester.pumpAndSettle();
    final badge = find.byKey(const Key('reskin-source-badge'));
    expect(find.descendant(of: badge, matching: find.text('gemini')), findsOne);

    await tester.enterText(
        find.byKey(const Key('reskin-prompt')), 'ذهبي على كحلي');
    await tester.tap(find.byKey(const Key('reskin-generate')));
    await tester.pumpAndSettle();

    expect(c.usedFallback, isTrue);
    expect(c.variants, hasLength(4));
    expect(find.byKey(const Key('reskin-loading')), findsNothing);
    expect(
        find.descendant(of: badge, matching: find.text('offline')), findsOne);
    expect(find.byKey(const Key('reskin-fallback-note')), findsOne);
    expect(find.textContaining('API key rejected (401)'), findsOne);
  });

  testWidgets('panel shows a loading line while the AI answers',
      (tester) async {
    final gate = Completer<http.Response>();
    final c = ReskinController(
        provider: GeminiThemeProvider(
            apiKey: 'k', client: MockClient((_) => gate.future)));
    await tester.pumpWidget(_app(c));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reskin-pill')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reskin-prompt')), 'ocean');
    await tester.tap(find.byKey(const Key('reskin-generate')));
    await tester.pump();
    expect(find.byKey(const Key('reskin-loading')), findsOne);
    expect(find.text('Asking gemini…'), findsOne);
    gate.complete(http.Response('nope', 500));
    await tester.pump(const Duration(seconds: 2)); // the one retry
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reskin-loading')), findsNothing);
    expect(c.usedFallback, isTrue);
  });
}
