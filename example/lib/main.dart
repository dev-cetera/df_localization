import 'package:df_localization/df_localization.dart';

import 'package:flutter/material.dart';

import 'api_keys.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

final translationManager = AutoTranslationManager.useFirestoreAndGoogleTranslator(
  translationPath: 'translations',
  projectId: 'langchapp',
  googleTranslateApiKey: GOOGLE_TRANSLATE_API_KEY,
);

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // final locale = primaryLocale(widgetsBinding);

  await translationManager.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PodBuilder(
      pod: AutoTranslationManager.pCache,
      builder: (context, snapshot) {
        return MaterialApp(
          key: UniqueKey(),
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(
                  onPressed: () {
                    translationManager.setLocale(const Locale('zh', 'CN'));
                  },
                  child: const Text('Chinese (CN)'),
                ),
                FilledButton(
                  onPressed: () {
                    translationManager.setLocale(const Locale('es', 'MX'));
                  },
                  child: const Text('Spanish (MX)'),
                ),
                FilledButton(
                  onPressed: () {
                    translationManager.setLocale(const Locale('de', 'DE'));
                  },
                  child: const Text('German (DE)'),
                ),
                FilledButton(
                  onPressed: () {
                    final locale = primaryLocale(WidgetsBinding.instance);
                    translationManager.setLocale(locale);
                  },
                  child: const Text('Default Locale'),
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
                    args: {'__OBJECT__': 'brewski'},
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
