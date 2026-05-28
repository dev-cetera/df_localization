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

import 'package:flutter/widgets.dart' show Locale, TextDirection;
import 'package:intl/intl.dart' show Bidi;

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Whether [locale] is a right-to-left language (Arabic, Hebrew,
/// Persian/Farsi, Urdu, Yiddish, Pashto, Sindhi, Uyghur, plus the
/// Thaana / N'Ko / Tifinagh scripts).
///
/// Delegates to `intl`'s [Bidi.isRtlLanguage], so the canonical
/// Unicode list stays in sync with the upstream intl package.
bool isRtlLocale(Locale locale) {
  return Bidi.isRtlLanguage(locale.toLanguageTag());
}

/// The natural [TextDirection] for [locale].
///
/// Returns [TextDirection.rtl] for Arabic / Hebrew / Persian / Urdu
/// etc., [TextDirection.ltr] for everything else. Use this when you
/// need to wrap a subtree in `Directionality` outside of a
/// `MaterialApp` (e.g. error boundaries, debug overlays, isolated
/// dialogs) — inside a MaterialApp the framework already does this
/// for you via [GlobalWidgetsLocalizations].
TextDirection getTextDirection(Locale locale) {
  return isRtlLocale(locale) ? TextDirection.rtl : TextDirection.ltr;
}
