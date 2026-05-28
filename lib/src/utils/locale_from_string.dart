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

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

Locale? localeFromString(String? localeString) {
  if (localeString == null || localeString.isEmpty) {
    return null;
  }
  final parts = localeString.split('-');
  if (parts.length == 1) {
    return Locale(parts[0].toLowerCase());
  }
  // BCP 47: language subtag is lowercase, region subtag is uppercase.
  // Without this normalisation, round-tripping `Locale('en','US')` through
  // [getNormalizedLanguageTag] (`en-us`) and back yields `Locale('en','us')`,
  // which is not == to the original and confuses host-app locale equality
  // checks (e.g. compledo's `pDeviceLocale` listener).
  final languageCode =
      parts.sublist(0, parts.length - 1).join('-').toLowerCase();
  final countryCode = parts.last.toUpperCase();
  return Locale(languageCode, countryCode);
}
