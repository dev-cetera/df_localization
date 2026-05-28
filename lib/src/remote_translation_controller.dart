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

import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Resolves a flat `key → string` translation map for a given [Locale].
///
/// The implementation is provided by the host app — typically a wrapper
/// around a backend endpoint (e.g. `GET /v1/translations?locale=...`) or an
/// offline-first cache such as `reliable`'s `ReliableRepository`. The
/// controller does not know or care where translations come from; it only
/// expects a flat string map keyed by the same key form used by `.tr()`.
typedef TFetchTranslations = Future<Map<String, String>> Function(
  Locale locale,
);

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// A translation controller for apps where translations are produced
/// server-side (or otherwise outside the client) and the client just needs
/// to fetch a flat key/value map per locale.
///
/// Compared to [AutoTranslationController], this controller intentionally
/// drops:
/// - the translator brokers (no LLM/Google calls from the client),
/// - the `DatabaseInterface` cache abstraction (offline caching is the
///   host fetcher's job — wire it through `reliable` or similar),
/// - the in-app auto-translate flow.
///
/// What it does:
/// 1. Owns a [pLocale] pod persisted to `SharedPreferences` under [cacheKey].
/// 2. Calls [fetchTranslations] whenever the locale changes and overwrites
///    [pCache] with the result.
/// 3. Installs a [FileConfig] on [TranslationManager] so existing `.tr()`
///    callsites continue to work.
///
/// Stale-load protection: concurrent locale changes are tagged with a
/// monotonic request id. Loads that resolve out of order are dropped.
class RemoteTranslationController {
  /// Called once per locale change to produce the translations map.
  final TFetchTranslations fetchTranslations;

  /// `SharedPreferences` key used to persist the current locale.
  final String cacheKey;

  RemoteTranslationController({
    required this.fetchTranslations,
    this.cacheKey = 'locale',
  });

  // ---------------------------------------------------------------------------

  final _pCache = Pod<Map<String, String>>(const {});

  /// Last-fetched flat translation map. Empty until [init] / [setLocale]
  /// resolves at least once.
  GenericPod<Map<String, String>> get pCache => _pCache;

  late final _pLocale = _createLocalePod(cacheKey: cacheKey);

  /// The active locale. Driven by [setLocale]; persisted across launches.
  GenericPod<Locale> get pLocale => _pLocale;

  Locale? get locale => _pLocale.getValue();

  // ---------------------------------------------------------------------------

  Future<void>? _initFuture;

  /// Run once at startup. Resolves when the first translation load
  /// completes (or fails). Idempotent — concurrent callers share the
  /// same Future.
  Future<void> init() => _initFuture ??= setLocale(null);

  // ---------------------------------------------------------------------------

  int _activeRequestId = 0;

  /// Switch to [locale] and refetch translations. Passing `null` resolves
  /// the platform locale (used by [init]).
  Future<void> setLocale(Locale? locale) async {
    final requestId = ++_activeRequestId;
    await _pLocale.refresh();
    if (locale != null) {
      await _pLocale.set(locale);
    } else if (this.locale == null) {
      await _pLocale.set(WidgetsBinding.instance.platformDispatcher.locale);
    }
    final activeLocale = this.locale!;
    ActiveLocale.set(activeLocale);
    Map<String, String> translations;
    try {
      translations = await fetchTranslations(activeLocale);
    } catch (e) {
      assert(false, 'Failed to fetch translations for $activeLocale: $e');
      translations = const {};
    }
    if (requestId != _activeRequestId) return;
    _pCache.set(translations);
    await _installConfig(translations);
  }

  // ---------------------------------------------------------------------------

  Future<void> _installConfig(Map<String, String> translations) async {
    await TranslationManager.setConfig(
      FileConfig(
        mapper: (textResult) {
          return translations[textResult.key] ?? textResult.defaultValue;
        },
      ),
    );
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
