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
  final ValueWidgetBuilder<Map<String, TranslatedText>?>? builder;
  final ValueWidgetBuilder<Map<String, TranslatedText>>? initializingBuilder;
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

  late final Future<ValueListenable<Map<String, TranslatedText>>> _pCache;

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
      pod: _pCache,
      builder: (context, snapshot) {
        return SizedBox(
          key: UniqueKey(),
          child: widget.builder?.call(
                context,
                snapshot.value,
                snapshot.child,
              ) ??
              snapshot.child,
        );
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
