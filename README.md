<a href="https://www.buymeacoffee.com/dev_cetera" target="_blank"><img align="right" src="https://cdn.buymeacoffee.com/buttons/default-orange.png" height="48"></a>
<a href="https://discord.gg/gEQ8y2nfyX" target="_blank"><img align="right" src="https://raw.githubusercontent.com/dev-cetera/resources/refs/heads/main/assets/discord_icon/discord_icon.svg" height="48"></a>

Dart & Flutter Packages by dev-cetera.com & contributors.

[![Pub Package](https://img.shields.io/pub/v/df_localization.svg)](https://pub.dev/packages/df_localization)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE)

---

## Summary

A package that provides an easy way to add localization support to your Flutter app. It supports automatic translation using Google Translator and Firebase, as well as manual translation using language files. All translations are cached for fast access and can be easily updated.

For a full feature set, please refer to the [API reference](https://pub.dev/documentation/df_localization/).

## Example 1 - Automatic Translation:

This is undoubtedly the simplest method to implement localization in your application. In debug mode, it automatically translates your text using Google Translate and saves the translations to a remote database. In release mode, this is disabled and it retrieves and caches the translations from the remote database for efficient use.

```dart
@override
Widget build(BuildContext context) {
  return AutoTranslationScope(
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
        locale: AutoTranslationScope.controllerOf(context)?.locale,
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
                    final locale = getPrimaryLocale(WidgetsBinding.instance);
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
                // This will display "Welcome to this app Robert" in English.
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
```

## Example - Translating From Langauge Files:

This is another way to use the package. It allows you to manually translate your text and store the translations in language files. This is useful when you want to have full control over your translations and don't want to rely on external services.

```dart
import 'package:df_localization/df_localization.dart';
import 'package:flutter/material.dart';

void main() {
  TranslationController.createInstance(
    translationsDirPath: 'assets/translations',
    // Use YAML files for translations. You can also use JSON files.
    fileType: ConfigFileType.YAML,
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
                  // Load translations from the 'en-us.yaml' file and rebuild the widget tree.
                  TranslationController.i.setLocale(const Locale('en', 'us'));
                },
                child: const Text('English (US)'),
              ),
              FilledButton(
                onPressed: () {
                  // Load translations from the 'de-de.yaml' file and rebuild the widget tree.
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
```

## Example - Generating Translation Files using Gemeni:

This is a more advanced way to use the package. It allows you to generate translation files for your app using the Gemeni API. Then you can manually edit the translations and use them in your app.

1. Translate text in your app like this:

```dart
import 'package:df_localization/df_localization.dart';

Text('Hello World'.tr());
Text('Hello World||hello-world'.tr()); // You can provide a key for the translation
Text('Hello {__WORLD__}'.tr(args: {'__WORLD__': 'World'})); // You can provide arguments for the translation
```

2. Obtain your Gemeni API key here: https://ai.google.dev/gemini-api/docs/api-key

3. Install the translation file generator tool:

```sh
dart pub global activate gen_translations_gemeni
```

3. Generate a translation file for your app, e.g. for German (de-de):

```sh
cd YOUR_FLUTTER_PROJECT
gen_translations_gemeni --locale "de-de" --api_key="YOUR_GEMENI_API_KEY" --output "assets/translations"
```

The following options are available:

```txt
-h, --help       Show this help message.
-r, --root       Root directory to search for translation keys.
                 (defaults to "/Users/robmllze/Projects/flutter/dev_cetera/df_packages/packages/df_localization/bin")
    --api_key    Obtain your API key here https://ai.google.dev/gemini-api/docs/api-key.
    --model      The Gemeni LLM to use.
                 (defaults to "gemini-1.5-flash-latest")
-l, --locale     Specify your locale or language, e.g. "en-us" or "English"
                 (defaults to "en-us")
-o, --output     Output directory path for the generated translation JSON.
                 (defaults to "/Users/robmllze/Projects/flutter/dev_cetera/df_packages/packages/df_localization/bin")
-t, --type       Specify your output file type, e.g. "yaml", "yml", "json", "jsonc".
                 (defaults to "yaml")
```

This will read your source code for all `.tr()` calls and send the text to Gemeni for translation. The generated translation file will be saved in `assets/translations/de-de.yaml`.

4. Edit the generated translation file in `assets/translations/de-de.yaml`:

```yaml
hello-world: Hallo Welt
```

5. Run your app with the new translation.

---

## Contributing and Discussions

This is an open-source project, and we warmly welcome contributions from everyone, regardless of experience level. Whether you're a seasoned developer or just starting out, contributing to this project is a fantastic way to learn, share your knowledge, and make a meaningful impact on the community.

### Ways you can contribute

- **Buy me a coffee:** If you'd like to support the project financially, consider [buying me a coffee](https://www.buymeacoffee.com/dev_cetera). Your support helps cover the costs of development and keeps the project growing.
- **Find us on Discord:** Feel free to ask questions and engage with the community here: https://discord.gg/gEQ8y2nfyX.
- **Share your ideas:** Every perspective matters, and your ideas can spark innovation.
- **Help others:** Engage with other users by offering advice, solutions, or troubleshooting assistance.
- **Report bugs:** Help us identify and fix issues to make the project more robust.
- **Suggest improvements or new features:** Your ideas can help shape the future of the project.
- **Help clarify documentation:** Good documentation is key to accessibility. You can make it easier for others to get started by improving or expanding our documentation.
- **Write articles:** Share your knowledge by writing tutorials, guides, or blog posts about your experiences with the project. It's a great way to contribute and help others learn.

No matter how you choose to contribute, your involvement is greatly appreciated and valued!

### We drink a lot of coffee...

If you're enjoying this package and find it valuable, consider showing your appreciation with a small donation. Every bit helps in supporting future development. You can donate here: https://www.buymeacoffee.com/dev_cetera

<a href="https://www.buymeacoffee.com/dev_cetera" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" height="40"></a>

## License

This project is released under the MIT License. See [LICENSE](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE) for more information.
