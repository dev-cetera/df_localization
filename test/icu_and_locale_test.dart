//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Copyright © dev-cetera.com & contributors.
//
// The use of this source code is governed by an MIT-style license described in
// the LICENSE file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import 'package:df_localization/df_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TranslationManager.resetForTesting();
    ActiveLocale.resetForTesting();
  });

  group('ICU plural / select expansion via .trIcu()', () {
    Future<TranslationController> makeController(
      Map<String, String> translations,
      Locale locale,
    ) async {
      final controller = TranslationController(
        translationsDirPath: 'assets/translations',
        fileType: ConfigFileType.YAML,
      );
      controller.setReader(
        TranslationFileReader(
          translationsDirPath: const ['assets', 'translations'],
          fileType: ConfigFileType.YAML,
          fileReader: (_) async {
            return translations.entries
                .map((e) => '${e.key}: "${e.value}"')
                .join('\n');
          },
        ),
      );
      await controller.setLocale(locale);
      return controller;
    }

    test('English plural with =0 / one / other branches', () async {
      await makeController(
        {
          'cart-items':
              '{count, plural, =0{Cart is empty} one{# item} other{# items}}',
        },
        const Locale('en', 'US'),
      );

      expect(
        'cart-items'.trIcu(args: {'count': 0}),
        equals('Cart is empty'),
      );
      expect(
        'cart-items'.trIcu(args: {'count': 1}),
        equals('1 item'),
      );
      expect(
        'cart-items'.trIcu(args: {'count': 5}),
        equals('5 items'),
      );
    });

    test('Russian plural — one / few / many CLDR rules', () async {
      await makeController(
        {
          'apples':
              '{count, plural, one{# яблоко} few{# яблока} many{# яблок} other{# яблока}}',
        },
        const Locale('ru', 'RU'),
      );

      expect('apples'.trIcu(args: {'count': 1}), equals('1 яблоко'));
      expect('apples'.trIcu(args: {'count': 3}), equals('3 яблока'));
      expect('apples'.trIcu(args: {'count': 5}), equals('5 яблок'));
    });

    test('select on gender', () async {
      await makeController(
        {
          'greet':
              '{gender, select, male{Welcome, sir} female{Welcome, madam} other{Welcome}}',
        },
        const Locale('en', 'US'),
      );

      expect(
        'greet'.trIcu(args: {'gender': 'male'}),
        equals('Welcome, sir'),
      );
      expect(
        'greet'.trIcu(args: {'gender': 'female'}),
        equals('Welcome, madam'),
      );
      expect(
        'greet'.trIcu(args: {'gender': 'unknown'}),
        equals('Welcome'),
      );
    });

    test('simple {name} placeholder still works', () async {
      await makeController(
        {'hello': 'Hello, {name}!'},
        const Locale('en', 'US'),
      );

      expect(
        'hello'.trIcu(args: {'name': 'Robert'}),
        equals('Hello, Robert!'),
      );
    });

    test('locale override beats ActiveLocale', () async {
      await makeController(
        {
          'apples':
              '{count, plural, one{# яблоко} few{# яблока} many{# яблок} other{# яблока}}',
        },
        const Locale('en', 'US'),
      );

      // ActiveLocale is now en-US — without override the English plural
      // rule fires (only `one` and `other`).
      expect('apples'.trIcu(args: {'count': 3}), equals('3 яблока'));
      // With explicit locale=ru, the Russian `few` rule fires.
      expect(
        'apples'.trIcu(args: {'count': 3}, locale: const Locale('ru')),
        equals('3 яблока'),
      );
      // And `many` for 5.
      expect(
        'apples'.trIcu(args: {'count': 5}, locale: const Locale('ru')),
        equals('5 яблок'),
      );
    });
  });

  group('RTL / text direction', () {
    test('isRtlLocale identifies Arabic, Hebrew, Persian, Urdu', () {
      expect(isRtlLocale(const Locale('ar')), isTrue);
      expect(isRtlLocale(const Locale('ar', 'EG')), isTrue);
      expect(isRtlLocale(const Locale('he')), isTrue);
      expect(isRtlLocale(const Locale('fa')), isTrue);
      expect(isRtlLocale(const Locale('ur')), isTrue);
    });

    test('isRtlLocale returns false for LTR languages', () {
      expect(isRtlLocale(const Locale('en')), isFalse);
      expect(isRtlLocale(const Locale('de', 'DE')), isFalse);
      expect(isRtlLocale(const Locale('ja')), isFalse);
      expect(isRtlLocale(const Locale('zh', 'CN')), isFalse);
    });

    test('getTextDirection maps to the right TextDirection', () {
      expect(getTextDirection(const Locale('ar')), TextDirection.rtl);
      expect(getTextDirection(const Locale('he')), TextDirection.rtl);
      expect(getTextDirection(const Locale('en')), TextDirection.ltr);
      expect(getTextDirection(const Locale('de')), TextDirection.ltr);
    });
  });

  group('bestLocale (MaterialApp.localeListResolutionCallback)', () {
    const supported = [
      Locale('en', 'US'),
      Locale('de', 'DE'),
      Locale('ar', 'EG'),
    ];

    test('exact language + country match wins', () {
      expect(
        bestLocale(supported, preferred: const [Locale('de', 'DE')]),
        equals(const Locale('de', 'DE')),
      );
    });

    test('language-only match when country differs', () {
      expect(
        bestLocale(supported, preferred: const [Locale('de', 'CH')]),
        equals(const Locale('de', 'DE')),
      );
    });

    test('first supported is the deterministic fallback', () {
      expect(
        bestLocale(supported, preferred: const [Locale('ja', 'JP')]),
        equals(const Locale('en', 'US')),
      );
    });

    test('priority order respects the preferred list', () {
      // Prefers de over ar when both are in preferred.
      expect(
        bestLocale(
          supported,
          preferred: const [Locale('de'), Locale('ar')],
        ),
        equals(const Locale('de', 'DE')),
      );
    });

    test('empty supported returns the system locale', () {
      expect(bestLocale(const <Locale>[]), equals(getSystemLocale()));
    });
  });

  group('ActiveLocale is updated by the controllers', () {
    test('TranslationController.setLocale updates ActiveLocale', () async {
      final controller = TranslationController(
        translationsDirPath: 'assets/translations',
      );
      controller.setReader(
        TranslationFileReader(
          translationsDirPath: const ['assets', 'translations'],
          fileType: ConfigFileType.YAML,
          // Valid YAML so the debug-mode assertion in `_readSafely` doesn't
          // fire; the keys themselves are irrelevant for this test.
          fileReader: (_) async => 'placeholder: ""\n',
        ),
      );

      await controller.setLocale(const Locale('ar', 'EG'));
      expect(ActiveLocale.current, equals(const Locale('ar', 'EG')));
      expect(isRtlLocale(ActiveLocale.current), isTrue);
    });
  });
}
