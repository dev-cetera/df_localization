import 'package:df_localization/df_localization.dart';
import 'package:flutter/foundation.dart';
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
    // Wrap your app with the `AutoTranslationScope` widget to provide
    // translations to your app.
    return AutoTranslationScope(
      // Customize how your app is translated to fit your needs.
      controller: AutoTranslationController(
        // Only do auto-translation in debug mode. This will store the
        // translations in your remote database, so when you run the app in
        // release mode, the translations are already available. This is
        // the default behavior.
        autoTranslate: kDebugMode,
        // Use the provided `FirestoreDatabseBroker` to store translations,
        // or define your own by extending the `DatabaseInterface` class.
        remoteDatabaseBroker: const FirestoreDatabseBroker(projectId: 'YOUR_FIREBASE_PROJECT_ID'),
        // Use the provided `GoogleTranslatorBroker` to translate text,
        // or define your own by extending the `TranslatorInterface` class.
        translationBroker: const GoogleTranslatorBroker(apiKey: 'YOUR_GOOGLE_TRANSLATOR_API_KEY'),
        // Use the provided `PersistentDatabaseBroker` to store translations locally,
        // or define your own by extending the `DatabaseInterface` class.
        persistentDatabaseBroker: const PersistentDatabaseBroker(),
      ),
      builder: (context, child) {
        return MaterialApp(
          // You can get the locale of the app using the `AutoTranslationScope.localeOf` method.
          locale: AutoTranslationScope.localeOf(context),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                spacing: 8.0,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Translate the app into the system language.
                  FilledButton(
                    onPressed: () {
                      // You can get the system locale of the device using
                      // the `getPrimaryLocale` method.
                      final locale = WidgetsBinding.instance.platformDispatcher.locale;
                      // You can access the controller using the
                      // `AutoTranslationScope.controllerOf` method.
                      AutoTranslationScope.controllerOf(context)?.setLocale(locale);
                    },
                    child: const Text('Default'),
                  ),
                  // Translate the app into English.
                  FilledButton(
                    onPressed: () {
                      AutoTranslationScope.controllerOf(
                        context,
                      )?.setLocale(const Locale('zh', 'CN'));
                    },
                    child: const Text('Chinese (CN)'),
                  ),
                  // Translate the app into Spanish.
                  FilledButton(
                    onPressed: () {
                      AutoTranslationScope.controllerOf(
                        context,
                      )?.setLocale(const Locale('es', 'MX'));
                    },
                    child: const Text('Spanish (MX)'),
                  ),
                  // Translate the app into German.
                  FilledButton(
                    onPressed: () {
                      AutoTranslationScope.controllerOf(
                        context,
                      )?.setLocale(const Locale('de', 'DE'));
                    },
                    child: const Text('German (DE)'),
                  ),
                  // This will display "Welcome to this app Robert" if the
                  // translation is not available or the language is English.
                  //
                  // The key "welcome_message" is optional and is uses as an
                  // identifier for the translation. If the key is not provided,
                  // the default text is used as the key.
                  //
                  // The "||" string is used to separate default text from the
                  // key.
                  //
                  // You can pass custom arguments to the translation using the
                  // `args` parameter. Place your placeholders between
                  // "{" and "}".
                  //
                  // The double underscore "__" is not necessary, but it helps
                  // Google Translate to ignore the placeholder and not
                  // translate it.
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
