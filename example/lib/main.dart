import 'package:df_localization/df_localization.dart';

import 'package:flutter/material.dart';

import 'api_keys.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

final manager = AutoTranslationManager.useFirestoreAndGoogleTranslator(
  projectId: 'langchapp',
  googleTranslateApiKey: GOOGLE_TRANSLATE_API_KEY,
);

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  final locale = primaryLocale(widgetsBinding);

  await manager.setLocale(locale);

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
                    manager.setLocale(const Locale('cn', 'CN'));
                  },
                  child: const Text('Chinese (CN)'),
                ),
                FilledButton(
                  onPressed: () {
                    manager.setLocale(const Locale('es', 'MX'));
                  },
                  child: const Text('Spanish (MX)'),
                ),
                FilledButton(
                  onPressed: () {
                    manager.setLocale(const Locale('de', 'DE'));
                  },
                  child: const Text('German (DE)'),
                ),
                FilledButton(
                  onPressed: () {
                    final locale = primaryLocale(WidgetsBinding.instance);
                    manager.setLocale(locale);
                  },
                  child: const Text('Default Locale'),
                ),
                Text('How are you {displayName}?||how_are_you'.tr(args: {'displayName': 'Robert'})),
                Text(
                  'Welcome to this app {displayName}||welcome_message'.tr(
                    args: {'displayName': 'Robert'},
                  ),
                ),
                Text(
                  'Hey there my man, do you want {object}||hey_there'.tr(
                    args: {'object': 'a brewski'},
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
