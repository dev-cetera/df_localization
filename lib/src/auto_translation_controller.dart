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

  /// When `true` (the default), every stored translation is keyed by its
  /// source-text version — `<key>@@<hash(source)>` — instead of the plain
  /// `<key>`. This is what keeps an already-deployed build reading the exact
  /// translation it shipped against: newer builds that edit a string write a
  /// *new* entry under a new hash rather than overwriting the shared one, so
  /// changing one string costs one new entry, not a copy of the database.
  ///
  /// Reads transparently fall back to a legacy plain-`<key>` entry whenever
  /// its stored `from` still matches the current source, so pre-versioning
  /// data keeps resolving without re-translating unchanged copy. Run
  /// [migrateToVersionedKeys] once to additively snapshot existing data.
  ///
  /// Set to `false` only to preserve the exact pre-0.7 plain-key behaviour.
  final bool versionBySourceText;

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
    this.versionBySourceText = true,
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
        final source = textResult.defaultValue;
        // Content-addressed lookup key: the same source copy always resolves
        // to the same entry, and edited copy resolves to a fresh one.
        final storageKey = versionBySourceText
            ? versionedTranslationKey(textKey, source)
            : textKey;
        final cache = _pCache.getValue();
        var hit = cache[storageKey];
        if (hit == null && versionBySourceText) {
          // Legacy fallback: a pre-versioning entry stored under the plain key
          // is still correct as long as its recorded source matches the copy
          // being rendered. Lets un-migrated databases keep resolving for new
          // clients without re-translating unchanged strings.
          final legacy = cache[textKey];
          if (legacy != null && legacy.from == source) {
            hit = legacy;
          }
        }
        final to = hit?.to;
        if (to != null) return to;
        // Cache miss: return the default English and, if enabled, translate in
        // the background under `storageKey`.
        if (autoTranslate && translationBroker != null) {
          // No global throttle: `_didRequestTranslate` already dedupes by
          // (versioned) key. Letting unique keys fire in parallel is the only
          // way the first-frame burst actually results in translations — the
          // previous global Throttle dropped every key but one.
          // Pin the locale + requestId at mapper-firing time so a locale
          // switch that happens during translation can't poison the
          // new-locale cache with an old-locale translation.
          _translateAndUpdate(
            source,
            storageKey,
            requestId,
            activeLocale,
          );
        }
        return source;
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

  /// One-time, idempotent, **additive** migration of pre-versioning data to
  /// source-versioned keys, for every configured database.
  ///
  /// For each existing plain `<key>` entry it *adds* a `<key>@@<hash(from)>`
  /// entry pointing at the same translation. The original plain key is
  /// **kept**, so builds already in the field — which still look translations
  /// up by the plain key — keep resolving, while newer builds resolve the
  /// versioned key. Safe to run more than once: entries that are already
  /// versioned (or already migrated) are skipped.
  ///
  /// Pass every [locales] you hold data for; the controller does not enumerate
  /// them. Typically called behind a dev/admin action, not on every launch.
  Future<void> migrateToVersionedKeys(Iterable<Locale> locales) async {
    final brokers = <DatabaseInterface?>[
      remoteDatabaseBroker,
      persistentDatabaseBroker,
    ];
    for (final broker in brokers) {
      if (broker == null) continue;
      for (final locale in locales) {
        await _migrateVersionedKeysFor(broker, locale);
      }
    }
  }

  Future<void> _migrateVersionedKeysFor(
    DatabaseInterface broker,
    Locale locale,
  ) async {
    final existing = await _loadTranslations(broker, locale);
    if (existing == null || existing.isEmpty) return;
    final additions = <String, TranslatedText>{};
    for (final entry in existing.entries) {
      final key = entry.key;
      final value = entry.value;
      final from = value.from;
      // Without a recorded source there is nothing to hash against.
      if (from == null) continue;
      final hash = translationSourceHash(from);
      final suffix = '$kTranslationVersionSeparator$hash';
      // Already versioned for this source — nothing to do.
      if (key.endsWith(suffix)) continue;
      final versionedKey = '$key$suffix';
      // Already migrated in a previous run.
      if (existing.containsKey(versionedKey)) continue;
      additions[versionedKey] = value;
    }
    if (additions.isEmpty) return;
    final path = _databasePath(translationPath, locale);
    // Await completion so callers can migrate one locale after another, then
    // discard the Outcome — migration is best-effort maintenance.
    (await broker.patch(path: path, data: _convertTo(additions)).value).end();
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
