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

import 'dart:async';

import 'package:df_localization/df_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Drains all pending microtasks + timers until [predicate] becomes true, or
/// [tries] timesteps have elapsed. The auto-translate flow chains several
/// Futures (translator → in-memory cache → DB patches), so a single
/// `Future.delayed(Duration.zero)` isn't enough.
Future<void> _pumpUntil(
  bool Function() predicate, {
  int tries = 50,
}) async {
  for (var i = 0; i < tries && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class _FakeDatabase extends DatabaseInterface {
  final Map<String, Map<String, dynamic>> store = {};
  final List<({String path, Map<String, dynamic> data})> patches = [];
  final List<({String path, Map<String, dynamic> data})> writes = [];
  final List<String> reads = [];

  @override
  Async<Map<String, dynamic>> read(String path) {
    return Async(() async {
      reads.add(path);
      final data = store[path];
      if (data == null) throw Err('not found: $path');
      return Map<String, dynamic>.from(data);
    });
  }

  @override
  Async<Unit> write({
    required String path,
    required Map<String, dynamic> data,
  }) {
    return Async(() async {
      writes.add((path: path, data: Map<String, dynamic>.from(data)));
      store[path] = Map<String, dynamic>.from(data);
      return Unit();
    });
  }

  @override
  Async<Unit> patch({
    required String path,
    required Map<String, dynamic> data,
  }) {
    return Async(() async {
      patches.add((path: path, data: Map<String, dynamic>.from(data)));
      final existing = store[path] ?? <String, dynamic>{};
      store[path] = {...existing, ...data};
      return Unit();
    });
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class _FakeTranslator extends TranslatorInterface<String> {
  final List<({String text, String lang, String? country})> calls = [];
  final String Function(String text, String lang, String? country) onTranslate;

  /// When non-null, the translator awaits this completer before returning —
  /// lets a test interleave a `setLocale` between request and response.
  Completer<void>? gate;

  _FakeTranslator(this.onTranslate) : super(apiKey: 'test-key');

  @override
  Async<String> translateSentence({
    required String text,
    required String languageCode,
    required String? countryCode,
  }) {
    return Async(() async {
      calls.add((text: text, lang: languageCode, country: countryCode));
      if (gate != null) await gate!.future;
      return onTranslate(text, languageCode, countryCode);
    });
  }

  @override
  Async<String> translate({required List<String> contents}) {
    return Async(() async => contents.join(' '));
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main() {
  // The SharedPod under the controller uses SharedPreferences; the test
  // binding must be initialised and the plugin stub must be in place.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TranslationManager.resetForTesting();
  });

  group('AutoTranslationController auto-translate flow', () {
    test('AI translates → in-memory cache + remote DB + persistent DB',
        () async {
      final remote = _FakeDatabase();
      final persistent = _FakeDatabase();
      final translator = _FakeTranslator((text, lang, _) => '[$lang]$text');

      final controller = AutoTranslationController(
        autoTranslate: true,
        cacheKey: 'locale_test_1',
        remoteDatabaseBroker: remote,
        persistentDatabaseBroker: persistent,
        translationBroker: translator,
      );

      await controller.init();
      await controller.setLocale(const Locale('de', 'DE'));

      // First `.tr()` call: cache miss. Returns the default string and
      // fires off the translation in the background.
      final first = 'Welcome||welcome_key'.tr();
      expect(first, equals('Welcome'));

      // Wait for the translation chain to complete patches on both DBs.
      await _pumpUntil(
        () => remote.patches.isNotEmpty && persistent.patches.isNotEmpty,
      );

      // In-memory cache holds the translated text.
      expect(
        controller.pCache.getValue()['welcome_key']?.to,
        equals('[de]Welcome'),
        reason: 'Translated value should land in the in-memory cache.',
      );

      // Both databases received a patch under the correct locale path.
      const expectedPath = 'translations/de-de';
      expect(remote.patches, hasLength(1));
      expect(remote.patches.single.path, equals(expectedPath));
      expect(
        remote.patches.single.data['welcome_key'],
        equals({'to': '[de]Welcome', 'from': 'Welcome'}),
      );
      expect(persistent.patches, hasLength(1));
      expect(persistent.patches.single.path, equals(expectedPath));
      expect(
        persistent.patches.single.data['welcome_key'],
        equals({'to': '[de]Welcome', 'from': 'Welcome'}),
      );

      // Second `.tr()` call: cache hit. No further translator call.
      final second = 'Welcome||welcome_key'.tr();
      expect(second, equals('[de]Welcome'));
      expect(translator.calls, hasLength(1));
    });

    test('release mode: a fresh controller loads from the remote DB', () async {
      final remote = _FakeDatabase()
        ..store['translations/de-de'] = {
          'welcome_key': {'to': 'Willkommen', 'from': 'Welcome'},
        };
      final persistent = _FakeDatabase();

      final controller = AutoTranslationController<DatabaseInterface,
          DatabaseInterface, TranslatorInterface<Object>>(
        autoTranslate: false,
        cacheKey: 'locale_test_2',
        remoteDatabaseBroker: remote,
        persistentDatabaseBroker: persistent,
        translationBroker: null,
      );

      await controller.init();
      await controller.setLocale(const Locale('de', 'DE'));

      // Remote translation lands in cache and resolves via `.tr()` directly.
      expect(controller.pCache.getValue()['welcome_key']?.to, 'Willkommen');
      expect('Welcome||welcome_key'.tr(), equals('Willkommen'));

      // Persistent cache should also be warmed from the remote read.
      await _pumpUntil(() => persistent.writes.isNotEmpty);
      expect(persistent.writes, isNotEmpty);
      expect(persistent.writes.last.path, equals('translations/de-de'));
    });

    test(
        'stale-locale guard: a de-translation that resolves AFTER a switch '
        'to fr does NOT poison the fr cache or fr DB path', () async {
      final remote = _FakeDatabase();
      final persistent = _FakeDatabase();
      final translator = _FakeTranslator((text, lang, _) => '[$lang]$text');
      translator.gate = Completer<void>();

      final controller = AutoTranslationController(
        autoTranslate: true,
        cacheKey: 'locale_test_3',
        remoteDatabaseBroker: remote,
        persistentDatabaseBroker: persistent,
        translationBroker: translator,
      );

      await controller.init();
      await controller.setLocale(const Locale('de', 'DE'));

      // Kick off translation for de.
      'Welcome||welcome_key'.tr();
      // Wait for the translator to register the call (so the await on `gate`
      // is genuinely in flight before we switch locales).
      await _pumpUntil(() => translator.calls.isNotEmpty);
      expect(translator.calls.single.lang, equals('de'));

      // Switch to fr while the de translation is paused on the gate.
      await controller.setLocale(const Locale('fr', 'FR'));

      // Release the de translation. It should be discarded.
      translator.gate!.complete();
      await _pumpUntil(() => false); // drain a few microtask turns

      // The de translation must not have been written to the fr path.
      expect(
        remote.patches.where((p) => p.path == 'translations/fr-fr'),
        isEmpty,
        reason: 'de translation must not appear under fr path',
      );
      expect(
        persistent.patches.where((p) => p.path == 'translations/fr-fr'),
        isEmpty,
        reason: 'de translation must not appear under fr path',
      );
      // And the in-memory cache (which is the fr cache now) must not hold
      // the de translation.
      expect(
        controller.pCache.getValue()['welcome_key']?.to,
        isNot(equals('[de]Welcome')),
      );
    });

    test('translator failure: cache stays untouched and the key is not retried',
        () async {
      final remote = _FakeDatabase();
      final persistent = _FakeDatabase();
      final translator = _FakeTranslator((_, __, ___) {
        throw Err('rate-limited', statusCode: 429);
      });

      final controller = AutoTranslationController(
        autoTranslate: true,
        cacheKey: 'locale_test_4',
        remoteDatabaseBroker: remote,
        persistentDatabaseBroker: persistent,
        translationBroker: translator,
      );

      await controller.init();
      await controller.setLocale(const Locale('de', 'DE'));

      'Welcome||welcome_key'.tr();
      await _pumpUntil(() => translator.calls.isNotEmpty);
      // Give the failed Async a few extra turns to settle.
      await _pumpUntil(() => false);

      // No DB writes on failure.
      expect(remote.patches, isEmpty);
      expect(persistent.patches, isEmpty);
      // Cache untouched.
      expect(controller.pCache.getValue()['welcome_key'], isNull);

      // Subsequent .tr() calls do NOT retry — _didRequestTranslate dedupes.
      'Welcome||welcome_key'.tr();
      'Welcome||welcome_key'.tr();
      await _pumpUntil(() => false);
      expect(translator.calls, hasLength(1));
    });
  });
}
