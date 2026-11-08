import 'package:bunn_showcase/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';

/// Runs the runtime X-ray on Home and returns the distinct source sites.
Future<Set<String>> xraySites(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const BunnApp());
  await tester.pump();
  final host = tester.state<ReskinHostState>(find.byType(ReskinHost));
  host.controller.setXray(true);
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
  return findings.map((f) => f.location).toSet();
}

void main() {
  testWidgets('X-ray on Home finds exactly the deliberately hardcoded colors',
      (tester) async {
    final sites = await xraySites(tester);
    // Set RESKIN_EXPECT_SITES=0 after `reskin-mcp fix` (see README).
    const expected =
        int.fromEnvironment('RESKIN_EXPECT_SITES', defaultValue: 7);
    expect(sites, hasLength(expected), reason: sites.join('\n'));
    if (expected > 0) {
      expect(sites.where((s) => s.startsWith('lib/widgets/promo_banner.dart:')),
          hasLength(4));
      expect(sites.where((s) => s.startsWith('lib/widgets/drink_tile.dart:')),
          hasLength(3));
    }
  });
}
