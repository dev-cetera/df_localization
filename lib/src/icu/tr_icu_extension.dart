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
    return MessageFormat(
      template,
      locale: effective.toLanguageTag(),
    ).format(args);
  }
}
