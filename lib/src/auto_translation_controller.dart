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

// ignore_for_file: body_might_complete_normally_nullable

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class AutoTranslationController<
    TRemoteDatabaseInterface extends DatabaseInterface,
    TCachedDatabaseInterface extends DatabaseInterface,
    TTranslationInterface extends TranslatorInterface> {
  //
  //
  //

  final bool autoTranslate;
  final TRemoteDatabaseInterface? remoteDatabaseBroker;
  final TCachedDatabaseInterface? persistentDatabaseBroker;
  final TTranslationInterface? translationBroker;
  final String cacheKey;
  final String translationPath;

  //
  //
  //

  AutoTranslationController({
    this.autoTranslate = kDebugMode,
    required this.remoteDatabaseBroker,
    this.persistentDatabaseBroker,
    this.translationBroker,
    this.cacheKey = 'locale',
    this.translationPath = 'translations',
  });

  //
  //
  //

  final _pCache = Pod<TTranslationMap>({});
  GenericPod<TTranslationMap> get pCache => _pCache;

  late final _pLocale = _createLocalePod(cacheKey: cacheKey);
  GenericPod<Locale> get pLocale => _pLocale;
  Locale? get locale => _pLocale.getValue();

  //
  //
  //

  // Caches the in-flight init so concurrent callers share one execution
  // rather than each running setLocale(null) end-to-end.
  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= setLocale(null);

  //
  //
  //

  // Monotonically increases on every setLocale call so older async loads
  // that resolve after a newer call can detect they are stale and bail.
  int _activeRequestId = 0;

  Future<void> setLocale(Locale? locale) async {
    final requestId = ++_activeRequestId;
    _didRequestTranslate.clear();
    await _pLocale.refresh();
    if (locale != null) {
      await _pLocale.set(locale);
    } else if (this.locale == null) {
      await _pLocale.set(WidgetsBinding.instance.platformDispatcher.locale);
    }
    final activeLocale = this.locale!;
    ActiveLocale.set(activeLocale);
    final cached =
        await _loadTranslations(persistentDatabaseBroker, activeLocale);
    if (requestId != _activeRequestId) return;
    final remote = _loadTranslations(remoteDatabaseBroker, activeLocale).then((
      result,
    ) {
      if (requestId != _activeRequestId) return result;
      final next = result ?? const <String, TranslatedText>{};
      _pCache.set(next);
      if (persistentDatabaseBroker != null) {
        _saveTranslations(persistentDatabaseBroker!, activeLocale, next).end();
      }
      return result;
    });
    if (cached == null) {
      await remote;
    } else {
      _pCache.set(cached);
    }
    if (requestId != _activeRequestId) return;
    await _installConfig(requestId, activeLocale);
  }

  //
  //
  //

  Future<void> _installConfig(int requestId, Locale activeLocale) async {
    final config = FileConfig(
      mapper: (textResult) {
        final textKey = textResult.key;
        String defaultValue;
        try {
          defaultValue = _pCache.getValue()[textKey]!.to!;
        } catch (_) {
          defaultValue = textResult.defaultValue;
          // Only attempt to translate if these conditions are met.
          if (autoTranslate && translationBroker != null) {
            // No global throttle: `_didRequestTranslate` already dedupes by
            // key. Letting unique keys fire in parallel is the only way the
            // first-frame burst actually results in translations — the
            // previous global Throttle dropped every key but one.
            // Pin the locale + requestId at mapper-firing time so a locale
            // switch that happens during translation can't poison the
            // new-locale cache with an old-locale translation.
            _translateAndUpdate(
              defaultValue,
              textKey,
              requestId,
              activeLocale,
            );
          }
        }
        return defaultValue;
      },
    );
    await TranslationManager.setConfig(config);
  }

  //
  //
  //

  Future<TTranslationMap?> _loadTranslations(
    DatabaseInterface? databaseBroker,
    Locale locale,
  ) async {
    if (databaseBroker == null) return null;
    try {
      final path = _databasePath(translationPath, locale);
      final input = await databaseBroker.read(path).value;
      if (input.isErr()) return null;
      UNSAFE:
      final fields = _convertFrom(input.unwrap());
      return fields;
    } catch (_) {
      // debugPrint(
      //   '[TranslationController._loadTranslations] Did not get translations for locale $locale with broker ${databaseBroker.runtimeType}.',
      // );
      return null;
    }
  }

  //
  //
  //

  Async<Unit> _saveTranslations(
    DatabaseInterface databaseBroker,
    Locale locale,
    TTranslationMap translations,
  ) {
    final path = _databasePath(translationPath, locale);
    final data = _convertTo(translations);
    return databaseBroker.write(path: path, data: data);
  }

  //
  //
  //

  // Ensures translateAndUpdate is called only once per key. This gets
  // reset in setLocale.
  final _didRequestTranslate = <String>{};

  Future<void> _translateAndUpdate(
    String defaultValue,
    String key,
    int requestId,
    Locale activeLocale,
  ) async {
    UNSAFE:
    {
      assert(autoTranslate, 'Auto-translation is disabled.');
      assert(translationBroker != null, 'Translation broker is not set.');

      // Safety check #1: If the key is already being translated or has already
      // been translated, we should not attempt to translate it again. This
      // check is necessary to prevent excessive API calls.
      if (_didRequestTranslate.contains(key)) return;
      _didRequestTranslate.add(key);

      // Safety check #2: If the key is already in the cache, we should not
      // attempt to translate it again.
      final test = _pCache.getValue()[key]?.to;
      if (test != null) return;

      final translated = await translationBroker!
          .translateSentence(
            text: defaultValue,
            languageCode: activeLocale.languageCode,
            countryCode: activeLocale.countryCode,
          )
          .value;

      // If the translation fails, no more attempts will be made since the
      // key is already added to _didRequestTranslate. This is deliberate to
      // prevent excessive API calls.
      if (translated.isErr()) return;

      // Bail if the locale was switched while we were translating — applying
      // an old-locale translation to the new-locale cache or DB would corrupt
      // it. The requestId check also covers re-init of the controller.
      if (requestId != _activeRequestId) return;

      final translatedText = TranslatedText(
        to: translated.unwrap(),
        from: defaultValue,
      );

      // Update the in-memory cache. Build a new map rather than mutating in
      // place — the previous value might be the `const {}` fallback from
      // `setLocale` (an empty remote result), and mutating that throws.
      _pCache.update((e) => {...e, key: translatedText});

      final path = _databasePath(translationPath, activeLocale);
      final patch = {key: translatedText.toMap()};

      // Update the persistent + remote databases in parallel.
      final futureResult1 =
          persistentDatabaseBroker?.patch(path: path, data: patch).value;
      final futureResult2 =
          remoteDatabaseBroker?.patch(path: path, data: patch).value;

      await Future.wait([
        if (futureResult1 != null) futureResult1,
        if (futureResult2 != null) futureResult2,
      ]);
    }
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

SharedPod<Locale, String> _createLocalePod({required String cacheKey}) {
  final fallbackLocale = WidgetsBinding.instance.platformDispatcher.locale;
  return SharedPod<Locale, String>(
    cacheKey,
    fromValue: (localeString) {
      return localeFromString(localeString) ?? fallbackLocale;
    },
    toValue: (locale) {
      return getNormalizedLanguageTag(locale);
    },
    initialValue: fallbackLocale,
  );
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// A model class that represents a translated text.
final class TranslatedText {
  final String? to;
  final String? from;

  const TranslatedText({required this.to, required this.from});

  Map<String, dynamic> toMap() {
    return {if (to != null) 'to': to, if (from != null) 'from': from};
  }

  factory TranslatedText.fromMap(Map<String, dynamic> map) {
    final to = map['to'];
    final from = map['from'];
    return TranslatedText(
      to: to is String ? to : null,
      from: from is String ? from : null,
    );
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

TTranslationMap _convertFrom(Map<String, dynamic> input) {
  return input.map((k, v) {
    final v1 = TranslatedText.fromMap((v as Map).cast());
    return MapEntry(k, v1);
  });
}

Map<String, dynamic> _convertTo(TTranslationMap input) {
  return input.map((k, v) => MapEntry(k, v.toMap()));
}

String _databasePath(String translationPath, Locale locale) {
  assert(translationPath.isNotEmpty);
  final parts = translationPath.split(RegExp(r'[/\\]'));
  final path = [...parts, getNormalizedLanguageTag(locale)].join('/');
  return path;
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

typedef TTranslationMap = Map<String, TranslatedText>;

/// Deprecated misspelling kept for one minor cycle. Prefer [TTranslationMap].
@Deprecated('Use TTranslationMap (correct spelling) instead.')
typedef TTransaltionMap = TTranslationMap;
