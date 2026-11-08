import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
              key: const Key('hard-container'),
              width: 50,
              height: 20,
              color: Colors.white),
          Container(
              key: const Key('themed-container'),
              width: 50,
              height: 20,
              color: cs.primary),
          Container(
            key: const Key('derived'),
            width: 50,
            height: 20,
            color: cs.primary.withValues(alpha: 0.2),
          ),
          // onPrimary is pure white in M3 light schemes: must NOT be flagged
          // just because it equals Colors.white.
          Container(width: 50, height: 20, color: cs.onPrimary),
          const Text('hard text', style: TextStyle(color: Colors.black87)),
          Text('themed text', style: TextStyle(color: cs.onSurface)),
          const Text('default text'),
          const Icon(Icons.star, color: Color(0xFF2F80ED)),
          Icon(Icons.star, color: cs.secondary),
          Container(
            width: 50,
            height: 20,
            decoration: BoxDecoration(
                color: const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }
}

Widget _app(ReskinController c) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: Reskin.builder(
          controller: c, enabled: true, registerServiceExtensions: false),
      home: const _Screen(),
    );

void main() {
  _contrastTests();

  testWidgets('X-ray skips inactive IndexedStack children', (tester) async {
    final c = ReskinController();
    await tester.pumpWidget(MaterialApp(
      builder: Reskin.builder(
          controller: c, enabled: true, registerServiceExtensions: false),
      home: const _Tabs(),
    ));
    final host = tester.state<ReskinHostState>(find.byType(ReskinHost));
    late List<XrayFinding> findings;
    await tester.runAsync(() async {
      final f = host.scanNow();
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        tester.binding.scheduleFrame();
        await tester.pump();
      }
      findings = await f;
    });
    expect(findings.map((f) => f.colorLabel).toList(),
        <String>['Color(0xFF112233)']);
  });

  testWidgets('X-ray flags only colors that ignore the theme', (tester) async {
    final c = ReskinController();
    await tester.pumpWidget(_app(c));
    final host = tester.state<ReskinHostState>(find.byType(ReskinHost));

    late List<XrayFinding> findings;
    await tester.runAsync(() async {
      final f = host.scanNow();
      // Drive frames while the probe waits for them.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        tester.binding.scheduleFrame();
        await tester.pump();
      }
      findings = await f;
    });

    final labels = findings.map((f) => f.colorLabel).toList()..sort();
    expect(labels, <String>[
      'Color(0xFF2F80ED)',
      'Color(0xFFF2F3F5)',
      'Colors.black87',
      'Colors.white',
    ]);
    // Theme-derived colors (primary, primary with alpha, onSurface, secondary)
    // are never flagged.
    expect(findings.every((f) => f.rect != null), isTrue);
    final white = findings.firstWhere((f) => f.colorLabel == 'Colors.white');
    expect(white.widgetType, 'Container');
    expect(white.property, 'color');
    if (isCreationTracked) {
      expect(white.file, endsWith('xray_test.dart'));
      expect(white.location, matches(RegExp(r'xray_test\.dart:\d+')));
    }
  });

  test('describeColor names Material colors', () {
    expect(describeColor(Colors.white), 'Colors.white');
    expect(describeColor(Colors.blue), 'Colors.blue');
    expect(describeColor(Colors.grey), 'Colors.grey');
    expect(describeColor(const Color(0xFF123456)), 'Color(0xFF123456)');
  });

  test('shortenPath keeps the lib-relative part', () {
    expect(shortenPath('file:///a/b/example/lib/home/offer_card.dart'),
        'lib/home/offer_card.dart');
    expect(shortenPath('/x/y/z.dart'), 'y/z.dart');
  });
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: IndexedStack(
        index: 0,
        children: <Widget>[
          SizedBox(
              width: 50,
              height: 20,
              child: ColoredBox(color: Color(0xFF112233))),
          // Inactive tab: laid out but never painted.
          SizedBox(
              width: 50,
              height: 20,
              child: ColoredBox(color: Color(0xFF445566))),
        ],
      ),
    );
  }
}

void _contrastTests() {
  test('makeReadable reports how many colors it changed', () {
    final bad = ColorScheme.fromSeed(seedColor: const Color(0xFFFFEB3B))
        .copyWith(
            onPrimary: const Color(0xFFFFFFFF),
            primary: const Color(0xFFFFF59D));
    final (fixed, n) = makeReadable(bad);
    expect(n, greaterThan(0));
    expect(ensureReadable(fixed).$2.passesAA, isTrue);
    final theme = const AiVariant(
      name: 'Lemon',
      light:
          AiPalette(primary: Color(0xFFFFF176), secondary: Color(0xFFFFEE58)),
    ).toTheme();
    expect(theme.lightFixes, greaterThan(0));
    expect(theme.fixesFor(Brightness.light), theme.lightFixes);
    expect(theme.copyWith(name: 'x').lightFixes, theme.lightFixes);
  });
}
