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

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart'
    show Locale, WidgetsBinding, visibleForTesting;

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

final class TranslationController {
  //
  //
  //

  static TranslationController get i {
    assert(
      _i != null,
      'TranslationController has not been initialized. Call createInstance first.',
    );
    return _i!;
  }

  static TranslationController? _i;

  /// Create a new instance of [TranslationController]. This instance
  /// will be stored in a static variable and can be accessed via
  /// [TranslationController.i].
  static TranslationController createInstance({
    required String translationsDirPath,
    ConfigFileType fileType = ConfigFileType.YAML,
  }) {
    assert(_i == null, 'TranslationController has already been initialized.');
    return _i ??= TranslationController(
      translationsDirPath: translationsDirPath,
      fileType: fileType,
    );
  }

  //
  //
  //

  late final String cacheKey;

  ///  The locale to use when the requested locale is not available. Defaults to
  /// the primary system locale.
  late final Locale fallbackLocale;

  ///  The path to the directory containing the translation files, e.g.
  /// 'assets/translations'.
  final String translationsDirPath;

  /// The type of file used to store translations.
  final ConfigFileType fileType;

  //
  //
  //

  TranslationController({
    required this.translationsDirPath,
    this.fileType = ConfigFileType.YAML,
  }) {
    cacheKey = 'locale';
    fallbackLocale = WidgetsBinding.instance.platformDispatcher.locale;
  }

  //
  //
  //

  /// Switch the active locale and load its translation file. The returned
  /// future resolves once `TranslationManager.config` has been swapped, so
  /// callers can safely call `.tr()` synchronously afterwards.
  Future<void> setLocale(Locale locale) async {
    await _pLocale.set(locale);
    ActiveLocale.set(locale);
    await _readSafely(locale);
  }

  late final _pLocale = _createLocalePod(cacheKey: cacheKey);
  GenericPod<Locale> get pLocale => _pLocale;
  Locale? get locale => _pLocale.getValue();

  SharedPod<Locale, String> _createLocalePod({required String cacheKey}) {
    return SharedPod<Locale, String>(
      cacheKey,
      // Triggered by the initial `refresh()` that the pod runs to pick up
      // a previously-persisted locale on app launch — that path needs to
      // load the translation file too, so we fire it from here. The set/
      // setLocale path goes through `setLocale` above and awaits the read
      // explicitly, so we don't need to re-fire it from `toValue`.
      fromValue: (localeString) {
        final next = localeFromString(localeString) ?? fallbackLocale;
        _readSafely(next).ignore();
        return next;
      },
      toValue: getNormalizedLanguageTag,
      initialValue: fallbackLocale,
    );
  }

  Future<void> _readSafely(Locale? locale) async {
    final languageTag = getNormalizedLanguageTag(locale ?? fallbackLocale);
    try {
      await _reader.read(languageTag);
    } catch (e) {
      assert(false, 'Failed to read translations for $languageTag: $e');
    }
  }

  //
  //
  //

  late var _reader = TranslationFileReader(
    translationsDirPath: _translationsDirPathSegments,
    fileType: fileType,
    fileReader: (filePath) {
      return rootBundle.loadString(filePath, cache: true);
    },
  );

  List<String> get _translationsDirPathSegments {
    return translationsDirPath.split(RegExp(r'[/\\]'));
  }

  @visibleForTesting
  void setReader(TranslationFileReader reader) {
    _reader = reader;
  }
}
