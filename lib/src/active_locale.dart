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

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Process-wide active [Locale]. Updated by each controller's `setLocale`,
/// read by ICU plural/select expansion and by RTL/text-direction helpers
/// that need to know the current language without depending on a specific
/// controller.
///
/// Reading is cheap and synchronous; if no controller has set the locale
/// yet, it falls back to the platform locale.
abstract final class ActiveLocale {
  static Locale? _current;

  /// The currently active locale. Falls back to
  /// `WidgetsBinding.instance.platformDispatcher.locale` when no
  /// controller has called [set] yet.
  static Locale get current {
    return _current ?? WidgetsBinding.instance.platformDispatcher.locale;
  }

  /// Called by each controller's `setLocale`. Apps don't normally call
  /// this directly — drive your controller and the controller updates
  /// this for you.
  static void set(Locale locale) {
    _current = locale;
  }

  /// Test seam — clears the cached locale so a subsequent read falls
  /// back to the platform locale again.
  @visibleForTesting
  static void resetForTesting() {
    _current = null;
  }
}
