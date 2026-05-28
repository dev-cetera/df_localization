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

import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// The device's primary system [Locale].
///
/// Works uniformly on every Flutter platform — iOS, Android, macOS,
/// Windows, Linux, and Web — because Flutter normalises the platform
/// locale lookup behind [PlatformDispatcher]. On Web this surfaces the
/// browser's `navigator.language`; on the native platforms it surfaces
/// the OS setting (Settings → Language, regedit's `LocaleName`, etc.).
///
/// Requires the Flutter binding to be initialised. In an app this is
/// already done by `runApp` / `WidgetsFlutterBinding.ensureInitialized()`.
Locale getSystemLocale() {
  return WidgetsBinding.instance.platformDispatcher.locale;
}

/// The device's preferred locales in priority order.
///
/// Use this when the user has more than one language enabled and you
/// want to fall back to a second-best choice if the primary one is
/// missing translations. On Web this is `navigator.languages`; on the
/// native platforms it's the user's ordered language list.
List<Locale> getSystemLocales() {
  return WidgetsBinding.instance.platformDispatcher.locales;
}
