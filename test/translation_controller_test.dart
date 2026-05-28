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
  });

  group('TranslationController (file-based)', () {
    test('setLocale awaits the file read — .tr() works synchronously after',
        () async {
      final controller = TranslationController(
        translationsDirPath: 'assets/translations',
        fileType: ConfigFileType.YAML,
      );
      controller.setReader(
        TranslationFileReader(
          translationsDirPath: const ['assets', 'translations'],
          fileType: ConfigFileType.YAML,
          fileReader: (path) async {
            // Return a tiny in-memory file keyed off the path.
            if (path.endsWith('de-de.yaml')) {
              return 'hello-world: Hallo Welt\n';
            }
            return '';
          },
        ),
      );

      await controller.setLocale(const Locale('de', 'DE'));

      // Synchronous .tr() must already see the German translation.
      expect('Hello World||hello-world'.tr(), equals('Hallo Welt'));
    });

    test('a missing key falls back to the default text after `||`', () async {
      final controller = TranslationController(
        translationsDirPath: 'assets/translations',
        fileType: ConfigFileType.YAML,
      );
      controller.setReader(
        TranslationFileReader(
          translationsDirPath: const ['assets', 'translations'],
          fileType: ConfigFileType.YAML,
          // File loads fine, but doesn't contain `hello-world`.
          fileReader: (_) async => 'other-key: Anderer Wert\n',
        ),
      );

      await controller.setLocale(const Locale('de', 'DE'));

      // Falls back to the default text after `||`.
      expect('Hello World||hello-world'.tr(), equals('Hello World'));
    });
  });

  group('System locale helpers', () {
    test('getSystemLocale returns the platform locale', () {
      expect(
        getSystemLocale(),
        equals(WidgetsBinding.instance.platformDispatcher.locale),
      );
    });

    test('getSystemLocales returns the preferred-locales list', () {
      expect(
        getSystemLocales(),
        equals(WidgetsBinding.instance.platformDispatcher.locales),
      );
    });
  });
}
