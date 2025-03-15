<a href="https://www.buymeacoffee.com/dev_cetera" target="_blank"><img align="right" src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

Dart & Flutter Packages by dev-cetera.com & contributors.

[![Pub Package](https://img.shields.io/pub/v/df_localization.svg)](https://pub.dev/packages/df_localization)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE)

---

## Summary

A package that provides an easy way to add localization support to your Flutter app. It supports automatic translation using Google Translator and Firebase, as well as manual translation using language files. All translations are cached for fast access and can be easily updated.

For a full feature set, please refer to the [API reference](https://pub.dev/documentation/df_localization/).

## Example - Automatic translation of your app using Google Translator and Firebase (or any other backend):

```dart
@override
Widget build(BuildContext context) {
  return AutoTranslationScope(
    controller: AutoTranslationController(
      remoteDatabaseBroker: const FirestoreDatabseBroker(projectId: 'YOUR_FIREBASE_PROJECT_ID'),
      persistentDatabaseBroker: const PersistentDatabaseBroker(),
    ),
    builder: (context, child) {
      return MaterialApp(
        locale: AutoTranslationScope.controllerOf(context)?.locale,
        home: Scaffold(
          body: Column(
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
      );
    },
  );
}
```

## Example - Translating your app from langauge files:

```dart
import 'package:df_localization/df_localization.dart';
import 'package:flutter/material.dart';

void main() {
  TranslationController.createInstance(translationsDirPath: 'assets/translations');
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
```

## Example - Generating translation files for your source code using Gemeni:

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

```
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

### Ways you can contribute:

- **Buy me a coffee:** If you'd like to support the project financially, consider [buying me a coffee](https://www.buymeacoffee.com/dev_cetera). Your support helps cover the costs of development and keeps the project growing.
- **Share your ideas:** Every perspective matters, and your ideas can spark innovation.
- **Report bugs:** Help us identify and fix issues to make the project more robust.
- **Suggest improvements or new features:** Your ideas can help shape the future of the project.
- **Help clarify documentation:** Good documentation is key to accessibility. You can make it easier for others to get started by improving or expanding our documentation.
- **Write articles:** Share your knowledge by writing tutorials, guides, or blog posts about your experiences with the project. It's a great way to contribute and help others learn.

No matter how you choose to contribute, your involvement is greatly appreciated and valued!

### Discord Server

Feel free to ask questions and engage with the community here: https://discord.gg/gEQ8y2nfyX

## Chief Maintainer:

📧 Email _Robert Mollentze_ at robmllze@gmail.com

## Dontations:

If you're enjoying this package and find it valuable, consider showing your appreciation with a small donation. Every bit helps in supporting future development. You can donate here:

https://www.buymeacoffee.com/dev_cetera

## License

This project is released under the MIT License. See [LICENSE](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE) for more information.
