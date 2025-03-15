import 'package:df_localization/df_localization.dart';
import 'package:flutter/material.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTranslationScope(
      controller: AutoTranslationController(
        remoteDatabaseBroker: const FirestoreDatabseBroker(projectId: 'YOUR_FIREBASE_PROJECT_ID'),
        translationBroker: const GeminiTranslatorBroker(apiKey: 'YOUR_GOOGLE_TRANSLATOR_API_KEY'),
        persistentDatabaseBroker: const PersistentDatabaseBroker(),
      ),
      builder: (context, child) {
        return MaterialApp(
          locale: AutoTranslationScope.controllerOf(context)?.locale,
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
                      AutoTranslationScope.controllerOf(context)?.setLocale(locale);
                    },
                    child: const Text('Default'),
                  ),
                  FilledButton(
                    onPressed: () {
                      AutoTranslationScope.controllerOf(
                        context,
                      )?.setLocale(const Locale('zh', 'CN'));
                    },
                    child: const Text('Chinese (CN)'),
                  ),
                  FilledButton(
                    onPressed: () {
                      AutoTranslationScope.controllerOf(
                        context,
                      )?.setLocale(const Locale('es', 'MX'));
                    },
                    child: const Text('Spanish (MX)'),
                  ),
                  FilledButton(
                    onPressed: () {
                      AutoTranslationScope.controllerOf(
                        context,
                      )?.setLocale(const Locale('de', 'DE'));
                    },
                    child: const Text('German (DE)'),
                  ),

                  Text(
                    'Welcome to this app {__DISPLAY_NAME__}||welcome_message'.tr(
                      args: {'__DISPLAY_NAME__': 'Robert'},
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
