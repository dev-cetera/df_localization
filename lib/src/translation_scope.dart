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

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░;

class TranslationScope extends StatefulWidget {
  //
  //
  //

  final TranslationController controller;
  final ValueWidgetBuilder<Locale?>? builder;
  final ValueWidgetBuilder<Locale>? initializingBuilder;
  final bool initialize;
  final Widget? child;

  //
  //
  //

  const TranslationScope({
    super.key,
    required this.controller,
    this.builder,
    this.initializingBuilder,
    this.initialize = true,
    this.child,
  }) : assert(builder != null || child != null);

  //
  //
  //

  static TranslationController? controllerOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InheritedTranslationScope>()?.controller;
  }

  //
  //
  //

  @override
  State<TranslationScope> createState() => _TranslationScopeState();
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░;

class _TranslationScopeState extends State<TranslationScope> {
  //
  //
  //

  late final Future<ValueListenable<Locale>> _pLocale;

  //
  //
  //

  @override
  void initState() {
    _pLocale = widget.controller.init().then((e) => widget.controller.pLocale);
    super.initState();
  }

  //
  //
  //

  @override
  Widget build(BuildContext context) {
    final podBuilder = PodBuilder(
      pod: _pLocale,
      builder: (context, snapshot) {
        return widget.builder?.call(
              context,
              snapshot.value,
              snapshot.child,
            ) ??
            snapshot.child ??
            const SizedBox();
      },
      child: widget.child,
    );
    return _InheritedTranslationScope(
      controller: widget.controller,
      child: podBuilder,
    );
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░;

class _InheritedTranslationScope extends InheritedWidget {
  //
  //
  //

  final TranslationController controller;

  //
  //
  //

  const _InheritedTranslationScope({
    required this.controller,
    required super.child,
  });

  //
  //
  //

  @override
  bool updateShouldNotify(_InheritedTranslationScope old) => true;
}
