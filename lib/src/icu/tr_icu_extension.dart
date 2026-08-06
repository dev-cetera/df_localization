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
import 'package:intl/message_format.dart';

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

extension TrIcuX on String {
  /// Like [tr] from `df_config`, but additionally expands ICU
  /// `plural` / `select` / `selectordinal` patterns against [args]
  /// for the [ActiveLocale.current] locale.
  ///
  /// Example translation file entry (YAML):
  /// ```yaml
  /// cart-items: "{count, plural, =0{Empty cart} one{# item} other{# items}}"
  /// ```
  ///
  /// Call site:
  /// ```dart
  /// Text('cart-items'.trIcu(args: {'count': cart.length}))
  /// ```
  ///
  /// Renders `Empty cart` / `1 item` / `5 items` according to the
  /// active locale's CLDR plural rules. Works with `select` (gender,
  /// case) and simple `{name}` placeholders too — anything ICU
  /// MessageFormat supports.
  ///
  /// The `df_config` secondary placeholder pass is skipped to avoid
  /// double-substitution; ICU `MessageFormat` does the placeholder
  /// expansion itself. If you don't need ICU features for a given
  /// string, prefer the existing `.tr()` extension.
  String trIcu({
    Map<String, Object>? args,
    String? preferKey,
    Locale? locale,
  }) {
    // Look up the raw template via `.tr()`. Disabling the secondary
    // settings pass prevents the `{name}` substitution that would
    // otherwise interfere with ICU braces.
    final template = tr(preferKey: preferKey, secondarySettings: null);
    if (args == null || args.isEmpty) return template;
    final effective = locale ?? ActiveLocale.current;
    final languageTag = effective.toLanguageTag();
    try {
      return MessageFormat(template, locale: languageTag).format(args);
    } catch (e, s) {
      // A malformed ICU template must never crash the host: `MessageFormat`
      // throws `mismatched { or }` during build when the template has
      // unbalanced braces (e.g. a damaged *stored* translation, or an
      // author typo). Forward the error so a host with an installed sink
      // can observe the misconfiguration, then degrade gracefully — this
      // mirrors `df_config`'s `tr()` best-effort guarantee.
      TranslationManager.reportError('trIcu', e, s);
      // Prefer the in-code source template — the part of this string
      // before the key delimiter (`'<icu-template>||key'`), which the
      // developer wrote and is presumed well-formed — so a corrupt stored
      // translation renders the source-language plural instead of raw ICU
      // syntax.
      final delimiter = TranslationManager.config.settings.delimiter;
      final delimiterIndex = delimiter.isEmpty ? -1 : lastIndexOf(delimiter);
      final source = delimiterIndex == -1 ? this : substring(0, delimiterIndex);
      if (source != template) {
        try {
          return MessageFormat(source, locale: languageTag).format(args);
        } catch (_) {
          // The source template is malformed too — fall through to raw.
        }
      }
      return source;
    }
  }
}
