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

// ignore_for_file: body_might_complete_normally_nullable

import 'package:flutter/foundation.dart' show kDebugMode;
// ignore: unused_shown_name
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding, debugPrint;

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
  final TRemoteDatabaseInterface remoteDatabaseBroker;
  final TCachedDatabaseInterface persistentDatabaseBroker;
  final TTranslationInterface translationBroker;
  final String cacheKey;
  final String translationPath;

  //
  //
  //

  AutoTranslationController({
    this.autoTranslate = kDebugMode,
    required this.remoteDatabaseBroker,
    required this.persistentDatabaseBroker,
    required this.translationBroker,
    this.cacheKey = 'locale',
    this.translationPath = 'translations',
  });

  //
  //
  //

  final _pCache = Pod<TTransaltionMap>({});
  ValueListenable<TTransaltionMap> get pCache => _pCache;

  SharedPod<Locale?, String>? _pLocale;
  ValueListenable<Locale?> get pLocale => _pLocale!;
  Locale? get locale => _pLocale!.value!;

  //
  //
  //

  // Ensures init is called only once.
  bool _didInit = false;

  Future<void> init() async {
    if (_didInit) return;
    await setLocale(null);
  }

  //
  //
  //

  Future<void> setLocale(Locale? locale) async {
    _didRequestTranslate.clear();
    await _initLocalePod();
    if (locale != null) {
      await _pLocale!.set(locale);
    } else if (this.locale == null) {
      await _pLocale!.set(getPrimaryLocale(WidgetsBinding.instance));
    }
    final a = await _loadTranslations(persistentDatabaseBroker, this.locale!);
    final b = _loadTranslations(remoteDatabaseBroker, this.locale!).then((
      c,
    ) {
      final d = c ?? {};
      _pCache.set(d);
      _saveTranslations(persistentDatabaseBroker, this.locale!, d);
      return c;
    });
    if (a == null) {
      await b;
    } else {
      _pCache.set(a);
    }
    _createTranslationManager();
    _didInit = true;
  }

  Future<void> _initLocalePod() async {
    if (_pLocale != null) return;
    _pLocale = _createLocalePod(cacheKey: cacheKey);
    await _pLocale!.refresh();
  }

  //
  //
  //

  void _createTranslationManager() {
    final config = FileConfig(
      mapper: (textResult) {
        final textKey = textResult.key;
        String defaultValue;
        try {
          defaultValue = _pCache.value[textKey]!.to!;
        } catch (_) {
          defaultValue = textResult.defaultValue;
          // Only attempt to translate if autoTranslate is enabled, a locale
          // exists and in debug mode.
          if (autoTranslate && this.locale != null) {
            _translateAndUpdateSequentally(defaultValue, textKey);
          }
        }
        return defaultValue;
      },
    );
    TranslationManager.config = config;
  }

  //
  //
  //

  Future<TTransaltionMap?> _loadTranslations(
    DatabaseInterface databaseBroker,
    Locale locale,
  ) async {
    try {
      final path = _databasePath(translationPath, locale);
      final input = await databaseBroker.read(path).value;
      if (input.isErr()) return null;
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

  Async<None> _saveTranslations(
    DatabaseInterface databaseBroker,
    Locale locale,
    TTransaltionMap translations,
  ) {
    final path = _databasePath(translationPath, locale);
    final data = _convertTo(translations);
    return databaseBroker.write(path: path, data: data);
  }

  //
  //
  //

  // Ensures translateAndUpdate is called sequentially.
  final _translationSeq = SafeSequential();

  // Ensures translateAndUpdate is called only once per key. This gets
  // reset in setLocale.
  final _didRequestTranslate = <String>{};

  Future<void> _translateAndUpdateSequentally(
    String defaultValue,
    String key,
  ) async {
    await _translationSeq.add((_) async {
      await _translateAndUpdate(defaultValue, key);
    }).value;
  }

  Future<void> _translateAndUpdate(String defaultValue, String key) async {
    assert(this.autoTranslate, 'Auto-translation is disabled.');
    assert(this.locale != null, 'Locale is not set.');

    // Safety check #1: If the key is already being translated or has already
    // been translated, we should not attempt to translate it again. This
    // check is necessary to prevent excessive API calls.
    if (_didRequestTranslate.contains(key)) return;
    _didRequestTranslate.add(key);

    // Safety check #2: If the key is already in the cache, we should not
    // attempt to translate it again.
    final test = _pCache.value[key]?.to;
    if (test != null) return;

    // debugPrint(
    //   '[TranslationController._createTranslationManager] Did not get translation for key: $key. Attempting to translate...',
    // );

    final translated = await translationBroker
        .translateSentence(
          text: defaultValue,
          languageCode: this.locale!.languageCode,
          countryCode: this.locale!.countryCode,
        )
        .value;

    // If the translation fails, no more attemps will be made since the
    // key is already added to _didRequestTranslate. This is deliberate to
    // prevent excessive API calls.
    if (translated.isErr()) return;

    // Update the cache in memory with the translated text.
    _pCache.update(
      (e) => e
        ..[key] = TranslatedText(
          to: translated.unwrap(),
          from: defaultValue,
        ),
    );

    final path = _databasePath(translationPath, this.locale!);

    // Update the persistent database.
    final futureResult1 = persistentDatabaseBroker.patch(
      path: path,
      data: {
        key: TranslatedText(
          to: translated.unwrap(),
          from: defaultValue,
        ).toMap(),
      },
    ).value;

    // Update the remote database.ßå
    final futureResult2 = remoteDatabaseBroker.patch(
      path: path,
      data: {
        key: TranslatedText(
          to: translated.unwrap(),
          from: defaultValue,
        ).toMap(),
      },
    ).value;

    final results = await Future.wait([futureResult1, futureResult2]);

    final result1 = results[0];
    final result2 = results[1];

    if (result1.isErr()) {
      // debugPrint(
      //   '[TranslationController._translateAndUpdate] Failed to update persistent database!',
      // );
    }

    if (result2.isErr()) {
      // debugPrint(
      //   '[TranslationController._translateAndUpdate] Failed to update remote database!',
      // );
    }
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

SharedPod<Locale, String> _createLocalePod({required String cacheKey}) {
  final fallbackLocale = getPrimaryLocale(WidgetsBinding.instance);
  return SharedPod<Locale, String>(
    cacheKey,
    fromValue: (localeString) async {
      return localeFromString(localeString) ?? fallbackLocale;
    },
    toValue: (locale) async {
      return getNormalizedLangaugeTag(locale ?? fallbackLocale);
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

TTransaltionMap _convertFrom(Map<String, dynamic> input) {
  return input.map((k, v) {
    final v1 = TranslatedText.fromMap((v as Map).cast());
    return MapEntry(k, v1);
  });
}

Map<String, dynamic> _convertTo(TTransaltionMap input) {
  return input.map((k, v) => MapEntry(k, v.toMap()));
}

String _databasePath(String translationPath, Locale locale) {
  assert(translationPath.isNotEmpty);
  final parts = translationPath.split(RegExp(r'[/\\]'));
  final path = [...parts, getNormalizedLangaugeTag(locale)].join('/');
  return path;
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

typedef TTransaltionMap = Map<String, TranslatedText>;
