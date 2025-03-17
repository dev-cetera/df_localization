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

import 'package:flutter/widgets.dart';

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class AutoTranslationScope extends StatefulWidget {
  //
  //
  //

  /// The controller that is used to manage the translations for this scope.
  /// Children can use the [controllerOf] method to access this controller,
  /// provided the [BuildContext] is within the scope of this widget.
  final AutoTranslationController controller;

  /// A builder that is used to build the widget after the translations
  /// have been initialized.
  final _ChildWidgetBuilder? builder;

  /// A builder that is used to build the widget while the translations
  /// are being initialized.
  final _ChildWidgetBuilder? initializingBuilder;

  /// Whether to initialize the translations immediately.
  final bool initialize;

  /// Determines how long to wait after the last translation request
  /// before updating the UI. For better performance, set this to a
  /// higher value, for better responsiveness, set this to a lower value.
  final Duration debounceDuration;

  /// The child widget. This is used if the [builder] is not provided and is
  /// also passed to the [builder] and [initializingBuilder].
  final Widget? child;

  //
  //
  //

  const AutoTranslationScope({
    super.key,
    required this.controller,
    this.builder,
    this.initializingBuilder,
    this.initialize = true,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.child,
  }) : assert(builder != null || child != null);

  //
  //
  //

  /// Returns the [AutoTranslationController] of the nearest
  /// [AutoTranslationScope] ancestor of the given [BuildContext].
  static AutoTranslationController? controllerOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AutoTranslationScope>()?.controller;
  }

  /// Returns the [Locale] of the nearest [AutoTranslationScope] ancestor
  /// of the given [BuildContext].
  static Locale? localeOf(BuildContext context) {
    return controllerOf(context)?.locale;
  }

  //
  //
  //

  @override
  State<AutoTranslationScope> createState() => _AutoTranslationScopeState();
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class _AutoTranslationScopeState extends State<AutoTranslationScope> {
  //
  //
  //

  late final Future<ValueListenable<TTransaltionMap>> _pCache;

  //
  //
  //

  @override
  void initState() {
    _pCache = widget.controller.init().then((e) {
      return widget.controller.pCache;
    });
    super.initState();
  }

  //
  //
  //

  @override
  Widget build(BuildContext context) {
    final podBuilder = PodBuilder(
      debounceDuration: widget.debounceDuration,
      pod: _pCache,
      builder: (context, snapshot) {
        final value = snapshot.value;
        final child = snapshot.child;
        return SizedBox(
          child: (value != null
                  ? widget.builder?.call(context, child)
                  : widget.initializingBuilder?.call(context, child)) ??
              child,
        );
      },
      child: widget.child,
    );
    return _AutoTranslationScope(
      controller: widget.controller,
      child: podBuilder,
    );
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class _AutoTranslationScope extends InheritedWidget {
  //
  //
  //

  final AutoTranslationController controller;

  //
  //
  //

  const _AutoTranslationScope({required this.controller, required super.child});

  //
  //
  //

  @override
  bool updateShouldNotify(_AutoTranslationScope old) => true;
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

typedef _ChildWidgetBuilder = Widget Function(BuildContext context, Widget? child);
