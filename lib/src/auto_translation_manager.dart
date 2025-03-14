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

import 'dart:ui' show Locale;

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class AutoTranslationManager<
    TRemoteDatabaseInterface extends DatabaseInterface,
    TCachedDatabaseInterface extends DatabaseInterface,
    TTranslationInterface extends TranslatorInterface> {
  //
  //
  //

  final String translationPath;
  final TRemoteDatabaseInterface remoteDatabaseBroker;
  final TCachedDatabaseInterface cachedDatabaseBroker;
  final TTranslationInterface translationBroker;

  static final pCache = Pod<Map<String, TranslatedText>>({});

  Locale? _currentLocale;

  final _initialInitCompleter = Completer<void>();

  final _didRequestTranslate = <String>{};

  static Map<String, TranslatedText> _castFields(Map<String, dynamic>? input) {
    return input?.map((k, v) {
          final v1 = TranslatedText.fromMap((v as Map).cast());
          return MapEntry(k, v1);
        }) ??
        {};
  }

  final _sequential = SafeSequential();

  //
  //
  //

  AutoTranslationManager({
    this.translationPath = 'translations',
    required this.remoteDatabaseBroker,
    required this.cachedDatabaseBroker,
    required this.translationBroker,
  });

  //
  //
  //

  static AutoTranslationManager<FirestoreDatabseBroker, PersistentDatabaseBroker,
      GoogleTranslatorBroker> useFirestoreAndGoogleTranslator({
    required String projectId,
    String? firestoreAccessToken,
    required String googleTranslateApiKey,
  }) {
    final remoteDatabaseBroker = FirestoreDatabseBroker(
      projectId: projectId,
      accessToken: firestoreAccessToken,
    );
    final translationBroker = GoogleTranslatorBroker(
      apiKey: googleTranslateApiKey,
    );
    return AutoTranslationManager(
      remoteDatabaseBroker: remoteDatabaseBroker,
      cachedDatabaseBroker: const PersistentDatabaseBroker(),
      translationBroker: translationBroker,
    );
  }

  //
  //
  //

  Future<void> setLocale(Locale locale) async {
    final a = await loadCachedTranslations(locale);
    final b = loadRemoteTranslations(locale);
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
          defaultValue = AutoTranslationManager.pCache.value[textKey]!.to;
        } catch (_) {
          // fail!
          defaultValue = textResult.defaultValue;
          /**/ translateAndUpdate(defaultValue, textKey);
        }
        return defaultValue;
      },
    );
    TranslationManager.config = config;
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
      _currentLocale = locale;
      final languageTag = locale.toLanguageTag().toLowerCase();
      final input = await remoteDatabaseBroker.read('$translationPath/$languageTag').value;
      if (input.isErr()) return false;
      final fields = _castFields(input.unwrap());
      pCache.update((e) => e..addAll(fields));
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
    final languageTag = _currentLocale!.toLanguageTag().toLowerCase();
    final result = await cachedDatabaseBroker
        .write(
          path: '$translationPath/$languageTag',
          data: pCache.value,
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
      _currentLocale = locale;
      final languageTag = locale.toLanguageTag().toLowerCase();
      final input = await cachedDatabaseBroker.read('$translationPath/$languageTag').value;
      if (input.isErr()) return false;
      final fields = _castFields(input.unwrap());
      pCache.update((e) => e..addAll(fields));
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
      final test = AutoTranslationManager.pCache.value[key]?.to;
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
    final locale = _currentLocale!;
    final languageTag = locale.toLanguageTag().toLowerCase();
    final translated = await translationBroker
        .translate(
          text: defaultValue,
          languageCode: locale.languageCode,
          countryCode: locale.countryCode,
        )
        .value;
    if (translated.isErr()) return;
    //print('TRANSLATED: $translated');
    pCache.update(
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

class TranslatedText {
  final String to;
  final String from;

  TranslatedText({
    required this.to,
    required this.from,
  });

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
