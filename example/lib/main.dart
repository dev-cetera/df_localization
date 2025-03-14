import 'package:df_localization/df_localization.dart';

import 'package:flutter/material.dart';

import 'api_keys.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TranslationScope(
      controller: TranslationController(
        remoteDatabaseBroker: const FirestoreDatabseBroker(projectId: 'langchapp'),
        translationBroker: const GoogleTranslatorBroker(apiKey: GOOGLE_TRANSLATE_API_KEY),
        cachedDatabaseBroker: const PersistentDatabaseBroker(),
      ),
      builder: (context, locale, child) {
        if (locale == null) {
          return const SizedBox.shrink();
        }
        return MaterialApp(
          locale: locale,
          key: UniqueKey(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                spacing: 8.0,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton(
                    onPressed: () {
                      final locale = primaryLocale(WidgetsBinding.instance);
                      TranslationScope.controllerOf(context)?.setLocale(locale);
                    },
                    child: const Text('Default'),
                  ),
                  FilledButton(
                    onPressed: () {
                      TranslationScope.controllerOf(context)?.setLocale(const Locale('zh', 'CN'));
                    },
                    child: const Text('Chinese (CN)'),
                  ),
                  FilledButton(
                    onPressed: () {
                      TranslationScope.controllerOf(context)?.setLocale(const Locale('es', 'MX'));
                    },
                    child: const Text('Spanish (MX)'),
                  ),
                  FilledButton(
                    onPressed: () {
                      TranslationScope.controllerOf(context)?.setLocale(const Locale('de', 'DE'));
                    },
                    child: const Text('German (DE)'),
                  ),

                  Text(
                    'How are you {__DISPLAY_NAME__}?||how_are_you'.tr(
                      args: {'__DISPLAY_NAME__': 'Robert'},
                    ),
                  ),
                  Text(
                    'Welcome to this app {__DISPLAY_NAME__}||welcome_message'.tr(
                      args: {'__DISPLAY_NAME__': 'Robert'},
                    ),
                  ),
                  Text(
                    'Hey there my man, do you want a {__OBJECT__}||hey_there'.tr(
                      args: {'__OBJECT__': 'ABC-2000'},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
