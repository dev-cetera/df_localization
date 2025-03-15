import 'package:df_localization/df_localization.dart';
import 'package:flutter/material.dart';

void main() {
  TranslationController.createInstance(
    translationsDirPath: 'assets/translations',
  );
  runApp(
    ValueListenableBuilder(
      valueListenable: TranslationController.i.pLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          locale: locale,
          home: Column(
            children: [
              Text('Hello World||hello-world'.tr()),
              FilledButton(
                onPressed: () {
                  TranslationController.i.setLocale(const Locale('en', 'us'));
                },
                child: const Text('English (US)'),
              ),
              FilledButton(
                onPressed: () {
                  TranslationController.i.setLocale(const Locale('de', 'de'));
                },
                child: const Text('Deutsch (DE)'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
