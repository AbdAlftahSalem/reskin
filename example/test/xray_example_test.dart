import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';
import 'package:reskin_example/main.dart';

void main() {
  testWidgets('X-ray finds the deliberately hardcoded colors', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BazaarApp());
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

    final sites = findings.map((f) => f.location).toSet();
    expect(sites, hasLength(7));
    expect(sites.where((s) => s.startsWith('lib/home/offer_card.dart:')),
        hasLength(4));
    expect(sites.where((s) => s.startsWith('lib/home/home_page.dart:')),
        hasLength(3));
    expect(findings.map((f) => f.colorLabel).toSet(),
        containsAll(<String>['Colors.white', 'Colors.black87', 'Colors.grey']));
  });
}
