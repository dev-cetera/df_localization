//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Dart/Flutter (DF) Packages by dev-cetera.com & contributors. The use of this
// source code is governed by an MIT-style license described in the LICENSE
// file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import 'package:flutter/widgets.dart';

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class TranslationController<
    TRemoteDatabaseInterface extends DatabaseInterface,
    TCachedDatabaseInterface extends DatabaseInterface,
    TTranslationInterface extends TranslatorInterface> {
  //
  //
  //

  final String cacheKey;
  final String translationPath;
  final TRemoteDatabaseInterface remoteDatabaseBroker;
  final TCachedDatabaseInterface cachedDatabaseBroker;
  final TTranslationInterface translationBroker;

  final _pCache = Pod<Map<String, TranslatedText>>({});
  ValueListenable<Map<String, TranslatedText>> get pCache => _pCache;

  SharedPod<Locale, String>? _pLocale;
  ValueListenable<Locale> get pLocale => _pLocale!.map((e) => e!);
  Locale get locale => _pLocale!.value!;

  final _initialInitCompleter = Completer<void>();

  final _didRequestTranslate = <String>{};

  final _sequential = SafeSequential();

  //
  //
  //

  TranslationController({
    required this.remoteDatabaseBroker,
    required this.cachedDatabaseBroker,
    required this.translationBroker,
    this.translationPath = 'translations',
    this.cacheKey = 'locale',
  });

  //
  //
  //

  static TranslationController<FirestoreDatabseBroker, PersistentDatabaseBroker,
      GoogleTranslatorBroker> useFirestoreAndGoogleTranslator({
    required String projectId,
    String? firestoreAccessToken,
    required String googleTranslateApiKey,
    String translationPath = 'translations',
    String cacheKey = 'locale',
  }) {
    final remoteDatabaseBroker = FirestoreDatabseBroker(
      projectId: projectId,
      accessToken: firestoreAccessToken,
    );
    final translationBroker = GoogleTranslatorBroker(
      apiKey: googleTranslateApiKey,
    );
    return TranslationController(
      remoteDatabaseBroker: remoteDatabaseBroker,
      cachedDatabaseBroker: const PersistentDatabaseBroker(),
      translationBroker: translationBroker,
      translationPath: translationPath,
      cacheKey: cacheKey,
    );
  }

  //
  //
  //

  bool _didInit = false;

  Future<void> init() async {
    if (_didInit) return;
    await setLocale(null);
  }

  //
  //
  //

  Future<void> setLocale(Locale? locale) async {
    await _initLocalePod();
    if (locale != null) {
      await _pLocale!.set(locale);
    }
    _pCache.update((e) => e..clear());
    final a = await loadCachedTranslations(this.locale);
    final b = loadRemoteTranslations(this.locale);
    // Wait for the remote translations to load before continuing if the cached
    // translations are not available.
    if (!a) {
      await b;
    }
    final config = FileConfig(
      mapper: (textResult) {
        final textKey = textResult.key;
        String defaultValue;
        try {
          defaultValue = _pCache.value[textKey]!.to;
        } catch (_) {
          // fail!
          defaultValue = textResult.defaultValue;
          /**/ translateAndUpdate(defaultValue, textKey);
        }
        return defaultValue;
      },
    );
    TranslationManager.config = config;
    _didInit = true;
  }

  Future<void> _initLocalePod() async {
    if (_pLocale != null) return;
    _pLocale = _createLocalePod(cacheKey: 'locale');
    await _pLocale!.refresh();
  }

  //
  //
  //

  Future<bool> loadRemoteTranslations(Locale locale) async {
    var success = false;
    await _sequential.add((_) async {
      try {
        success = await _loadRemoteTranslations(locale);
      } catch (_) {}
      if (!_initialInitCompleter.isCompleted) {
        _initialInitCompleter.complete();
      }
      return const None();
    }).value;
    if (!success) {
      // fail!
    }
    return success;
  }

  //
  //
  //

  Future<bool> _loadRemoteTranslations(Locale locale) async {
    try {
      final languageTag = locale.toLanguageTag().toLowerCase();
      final input = await remoteDatabaseBroker.read('$translationPath/$languageTag').value;
      if (input.isErr()) return false;
      final fields = TranslatedText._castFields(input.unwrap());
      _pCache.update((e) => e..addAll(fields));
      await _saveCache();
      return true;
    } catch (_) {
      // fail!
      return false;
    }
  }

  //
  //
  //

  Future<void> _saveCache() async {
    final languageTag = this.locale.toLanguageTag().toLowerCase();
    final result = await cachedDatabaseBroker
        .write(
          path: '$translationPath/$languageTag',
          data: _pCache.value,
        )
        .value;
    if (result.isErr()) {
      // fail!
    }
  }

  //
  //
  //

  Future<bool> loadCachedTranslations(Locale locale) async {
    try {
      final languageTag = locale.toLanguageTag().toLowerCase();
      final input = await cachedDatabaseBroker.read('$translationPath/$languageTag').value;
      if (input.isErr()) return false;
      final fields = TranslatedText._castFields(input.unwrap());
      _pCache.update((e) => e..addAll(fields));
      return true;
    } catch (_) {
      // fail!
      return false;
    }
  }

  //
  //
  //

  Future<void> translateAndUpdate(String defaultValue, String key) async {
    await _sequential.add((_) async {
      await _initialInitCompleter.future;
      final test = _pCache.value[key]?.to;
      //if (test == null) {
      await _translateAndUpdate(defaultValue, key);
      //}
      return const None();
    }).value;
  }

  //
  //
  //

  Future<void> _translateAndUpdate(String defaultValue, String key) async {
    if (_didRequestTranslate.contains(key)) return;
    _didRequestTranslate.add(key);
    final languageTag = this.locale.toLanguageTag().toLowerCase();
    final translated = await translationBroker
        .translate(
          text: defaultValue,
          languageCode: this.locale.languageCode,
          countryCode: this.locale.countryCode,
        )
        .value;
    if (translated.isErr()) return;
    //print('TRANSLATED: $translated');
    _pCache.update(
      (e) => e
        ..[key] = TranslatedText(
          to: translated.unwrap(),
          from: defaultValue,
        ),
    );
    //print('TO LOCAL: $languageTag');
    final f1 = cachedDatabaseBroker.patch(
      path: '$translationPath/$languageTag',
      data: {
        key: TranslatedText(to: translated.unwrap(), from: defaultValue).toMap(),
      },
    ).value;
    //print('TO REMOTE: $languageTag');

    final f2 = remoteDatabaseBroker.patch(
      path: '$translationPath/$languageTag',
      data: {
        key: TranslatedText(
          to: translated.unwrap(),
          from: defaultValue,
        ).toMap(),
      },
    ).value;

    await Future.wait([f1, f2]);
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

SharedPod<Locale, String> _createLocalePod({
  required String cacheKey,
}) {
  final fallbackLocale = primaryLocale(WidgetsBinding.instance);
  return SharedPod<Locale, String>(
    cacheKey,
    fromValue: (localeString) async {
      final locale = () {
        if (localeString == null || localeString.isEmpty) {
          return fallbackLocale;
        }
        final parts = localeString.split('-');
        if (parts.length == 1) {
          final languageCode = parts[0];
          return Locale(languageCode);
        } else {
          final languageCode = parts.sublist(0, parts.length - 1).join('-');
          final countryCode = parts.last;
          return Locale(languageCode, countryCode);
        }
      }();
      return locale;
    },
    toValue: (locale) async {
      final languageTag = (locale ?? fallbackLocale).toLanguageTag().toLowerCase();
      return languageTag;
    },
    initialValue: fallbackLocale,
  );
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class TranslatedText {
  final String to;
  final String from;

  const TranslatedText({
    required this.to,
    required this.from,
  });

  static Map<String, TranslatedText> _castFields(Map<String, dynamic>? input) {
    return input?.map((k, v) {
          final v1 = TranslatedText.fromMap((v as Map).cast());
          return MapEntry(k, v1);
        }) ??
        {};
  }

  Map<String, dynamic> toMap() {
    return {
      'to': to,
      'from': from,
    };
  }

  factory TranslatedText.fromMap(Map<String, dynamic> map) {
    return TranslatedText(
      to: map['to'] as String,
      from: map['from'] as String,
    );
  }
}
