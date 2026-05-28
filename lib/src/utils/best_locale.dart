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

import 'package:flutter/widgets.dart' show Locale;

import 'get_system_locale.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Picks the best [Locale] from [supported] that matches one of the
/// device's preferred locales.
///
/// Designed to drop straight into Flutter's
/// [WidgetsApp.localeListResolutionCallback]:
///
/// ```dart
/// MaterialApp(
///   supportedLocales: const [Locale('en'), Locale('de'), Locale('ar')],
///   localeListResolutionCallback: (preferred, supported) =>
///       bestLocale(supported, preferred: preferred),
///   ...
/// );
/// ```
///
/// Resolution priority (first match wins):
///   1. Exact language + country match.
///   2. Language-only match.
///   3. The first entry of [supported] (so a non-empty `supportedLocales`
///      always produces a deterministic answer rather than `null`).
///
/// If [preferred] is null, [getSystemLocales] is used — the device's
/// ordered language list. This matches Flutter's own
/// `basicLocaleListResolution` semantics closely enough for the typical
/// app use case while staying readable.
Locale bestLocale(
  Iterable<Locale> supported, {
  Iterable<Locale>? preferred,
}) {
  final supportedList = supported.toList(growable: false);
  if (supportedList.isEmpty) {
    return getSystemLocale();
  }
  final candidates = (preferred ?? getSystemLocales()).toList(growable: false);

  // 1) Exact match on language + country.
  for (final candidate in candidates) {
    for (final option in supportedList) {
      if (option.languageCode == candidate.languageCode &&
          option.countryCode == candidate.countryCode) {
        return option;
      }
    }
  }
  // 2) Language-only match.
  for (final candidate in candidates) {
    for (final option in supportedList) {
      if (option.languageCode == candidate.languageCode) {
        return option;
      }
    }
  }
  // 3) Deterministic fallback.
  return supportedList.first;
}
