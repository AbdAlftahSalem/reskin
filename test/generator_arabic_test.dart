import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reskin/reskin.dart';

void main() {
  test('Arabic color words: «ذهبي على كحلي» is gold on navy', () {
    final i = parsePrompt('ذهبي على كحلي');
    expect(i.accent, kColorWords['gold']);
    expect(i.background, kColorWords['navy']);
    expect(i.seed, kColorWords['navy']);
    expect(i.title, 'ذهبي على كحلي');
  });

  test('Arabic prefixes, feminine forms and spelling variants match', () {
    expect(arabicKey('الأخضر'), 'green');
    expect(arabicKey('والذهبي'), 'gold');
    expect(arabicKey('ذهبية'), 'gold');
    expect(arabicKey('زرقاء'), 'blue');
    expect(arabicKey('أحمر'), 'red');
    expect(arabicKey('احمر'), 'red');
    expect(arabicKey('بني'), 'brown');
    expect(arabicKey('قَهْوَة'), 'coffee', reason: 'diacritics are ignored');
    expect(arabicKey('كلمة'), isNull);
  });

  test('«ألوان قهوة الصبح» understands coffee + morning', () {
    final i = parsePrompt('ألوان قهوة الصبح');
    expect(i.matched, containsAll(<String>['قهوة', 'الصبح']));
    expect(i.seed, kColorWords['coffee']);
    expect(i.title, 'ألوان قهوة');
  });

  test('Arabic moods set fonts: «رمضان ذهبي على كحلي»', () {
    final i = parsePrompt('رمضان، ذهبي على كحلي');
    expect(i.headingFont, 'El Messiri');
    expect(i.accent, kColorWords['gold']);
    expect(i.background, kColorWords['navy']);
  });

  test('mixed Arabic + English prompts', () {
    final i = parsePrompt('تطبيق طبي calm أخضر');
    expect(i.matched, containsAll(<String>['طبي', 'calm', 'أخضر']));
    expect(i.seed, isNot(isNull));
  });

  test('new English words degrade gracefully', () {
    expect(parsePrompt('morning coffee colors').seed, kColorWords['coffee']);
    expect(parsePrompt('cyberpunk neon').background, isNotNull);
    expect(parsePrompt('calm medical app for students').matched,
        containsAll(<String>['calm', 'medical', 'students']));
    expect(parsePrompt('terracotta on ivory').background, kColorWords['ivory']);
  });

  test('Arabic offline themes are readable and deterministic', () async {
    const p = OfflineThemeProvider();
    final a = await p.generate(const ReskinPrompt.text('أخضر زيتي هادئ'));
    final b = await p.generate(const ReskinPrompt.text('أخضر زيتي هادئ'));
    expect(a, hasLength(4));
    for (var k = 0; k < a.length; k++) {
      expect(a[k].light, b[k].light);
      expect(ensureReadable(a[k].light).$2.adjustedCount, 0);
      expect(ensureReadable(a[k].dark).$2.adjustedCount, 0);
    }
    final hue = HSLColor.fromColor(a.first.light.primary).hue;
    expect(hue, inInclusiveRange(70, 160), reason: 'green family');
  });
}
