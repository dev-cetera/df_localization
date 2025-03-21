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

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding, visibleForTesting;

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
  }) {
    assert(_i == null, 'TranslationController has already been initialized.');
    return _i ??= TranslationController(
      translationsDirPath: translationsDirPath,
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

  Future<void> setLocale(Locale locale) => _pLocale!.set(locale);

  SharedPod<Locale, String>? _pLocale;
  ValueListenable<Locale?> get pLocale =>
      _pLocale ??= _createLocalePod(cacheKey: cacheKey)..refresh();

  SharedPod<Locale, String> _createLocalePod({required String cacheKey}) {
    final fallbackLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return SharedPod<Locale, String>(
      cacheKey,
      fromValue: (localeString) async {
        final locale = localeFromString(localeString) ?? fallbackLocale;
        _read(locale);
        return locale;
      },
      toValue: (locale) async {
        _read(locale);
        return getNormalizedLangaugeTag(locale ?? fallbackLocale);
      },
      initialValue: fallbackLocale,
    );
  }

  void _read(Locale? locale) async {
    final languageTag = getNormalizedLangaugeTag(locale ?? fallbackLocale);
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
