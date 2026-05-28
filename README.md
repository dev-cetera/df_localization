[![pub](https://img.shields.io/pub/v/df_localization.svg)](https://pub.dev/packages/df_localization)
[![tag](https://img.shields.io/badge/Tag-v0.7.0-purple?logo=github)](https://github.com/dev-cetera/df_localization/tree/v0.7.0)
[![buymeacoffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/dev_cetera)
[![sponsor](https://img.shields.io/badge/Sponsor-grey?logo=github-sponsors&logoColor=pink)](https://github.com/sponsors/dev-cetera)
[![patreon](https://img.shields.io/badge/Patreon-grey?logo=patreon)](https://www.patreon.com/robelator)
[![discord](https://img.shields.io/badge/Discord-5865F2?logo=discord&logoColor=white)](https://discord.gg/gEQ8y2nfyX)
[![instagram](https://img.shields.io/badge/Instagram-E4405F?logo=instagram&logoColor=white)](https://www.instagram.com/dev_cetera/)
[![license](https://img.shields.io/badge/License-MIT-blue.svg)](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE)

---

<!-- BEGIN _README_CONTENT -->

## Summary

A package that simplifies adding localization to your Flutter app. It supports automatic translation using your preferred translation service, as well as manual translation using language files (JSON or YAML). All translations are cached for fast access and can be easily updated.

### Why Use This Package?

- Simplifies localization with automatic and manual translation options.
- Built-in translation services: **Google Translate**, plus any LLM (**Claude, Gemini, OpenAI**, or a custom provider) through a single `LlmTranslatorBroker` backed by [`ai_broker`](https://pub.dev/packages/ai_broker).
- Built-in storage: **Firebase Firestore** for the remote database and **SharedPreferences** for local caching. The `DatabaseInterface` / `TranslatorInterface` contracts are tiny — swap any of them out for your own.
- Caches translations for faster performance, offline access, and reduced API costs.
- The alternative manual translation method supports multiple file formats (JSON, YAML).
- **Standard ICU MessageFormat** support via `.trIcu()` — plural / select / gender, all the CLDR plural rules per locale.
- **Right-to-left aware** out of the box — `isRtlLocale()` / `getTextDirection()` helpers plus seamless interaction with Flutter's `Directionality`.
- One-line `getSystemLocale()` / `getSystemLocales()` / `bestLocale()` helpers work on iOS, Android, macOS, Windows, Linux, and Web.
- Plays nicely with Flutter's existing i18n machinery (`MaterialApp.locale`, `supportedLocales`, `localeListResolutionCallback`, `Directionality`).
- Super easy to integrate and customize for your app's needs.

## Example 1 - Automatic Translation:

This is the easiest way to add localization to your app. In debug mode, it automatically translates your text using Google Translate and stores the translations in a remote database (e.g., Firebase Firestore). In release mode, automatic translation is disabled, and the app retrieves and caches translations from the remote database for optimal performance.

```dart
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
                    // `getSystemLocale()` works on every Flutter platform —
                    // iOS, Android, macOS, Windows, Linux, Web.
                    AutoTranslationScope.controllerOf(
                      context,
                    )?.setLocale(getSystemLocale());
                  },
                  child: const Text('Default'),
                ),
                // Translate the app into Chinese.
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
```

## Example 2 - Using any LLM (Claude / Gemini / OpenAI):

Swap out `GoogleTranslatorBroker` for `LlmTranslatorBroker` to translate via an LLM. The same class drives every provider — pick the named constructor that matches your API key, or pass any `AiBroker` instance for a provider not listed here.

```dart
// Anthropic Claude
translationBroker: LlmTranslatorBroker.claude(apiKey: 'YOUR_ANTHROPIC_KEY'),

// Google Gemini
translationBroker: LlmTranslatorBroker.gemini(apiKey: 'YOUR_GEMINI_KEY'),

// OpenAI
translationBroker: LlmTranslatorBroker.openai(apiKey: 'YOUR_OPENAI_KEY'),

// Any other provider — pass your own AiBroker implementation.
translationBroker: LlmTranslatorBroker(
  apiKey: 'YOUR_KEY',
  broker: MyCustomBroker(),
  model: 'my-model-id',
),
```

Every constructor accepts an optional `model`, `systemPrompt`, `temperature`, and `maxTokens`. The defaults are tuned for short UI strings — low temperature, a system prompt that tells the model to leave `{...}` / `{{...}}` placeholders untouched.

## Example 3 - Translating From language Files:

This method allows you to manually translate text and store translations in language files (JSON or YAML). It's ideal for scenarios where you want full control over translations or need to work offline without relying on external services.

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

## Example 4 - Generating Translation Files via any LLM:

This advanced method uses an LLM (Claude, Gemini, or OpenAI) to generate translation files for your app. After generating the files, you can manually edit them for accuracy and use them in your app. This is ideal for automating initial translations while retaining control over the final output.

1. Translate text in your app like this:

```dart
import 'package:df_localization/df_localization.dart';

Text('Hello World'.tr());
Text('Hello World||hello-world'.tr()); // You can provide a key for the translation
Text('Hello {__WORLD__}'.tr(args: {'__WORLD__': 'World'})); // You can provide arguments for the translation
```

2. Obtain an API key from your provider of choice:
   - Anthropic: https://console.anthropic.com/
   - Google (Gemini): https://ai.google.dev/gemini-api/docs/api-key
   - OpenAI: https://platform.openai.com/

3. Install the translation file generator tool:

```sh
dart pub global activate df_localization
```

4. Generate a translation file for your app, e.g. for German (de-de) via Claude:

```sh
cd YOUR_FLUTTER_PROJECT
gen-translations --provider claude --locale "de-de" --api_key "YOUR_API_KEY" --output "assets/translations"
```

The following options are available:

```txt
-h, --help       Show this help message.
-r, --root       Root directory to search for translation keys.
                 (defaults to the current directory)
-p, --provider   Which LLM to use. One of "claude", "gemini", "openai".
                 (defaults to "gemini")
    --api_key    Your provider API key.
    --model      Model id. Per-provider defaults are used if omitted.
-l, --locale     Specify your locale or language, e.g. "en-us" or "English".
                 (defaults to "en-us")
-o, --output     Output directory path for the generated translation file.
                 (defaults to the current directory)
-t, --type       Output file type: "yaml", "yml", "json", or "jsonc".
                 (defaults to "yaml")
```

This will read your source code for all `.tr()` calls and send the collected strings to the chosen LLM for translation. The generated translation file will be saved in `assets/translations/de-de.yaml`.

5. Edit the generated translation file in `assets/translations/de-de.yaml`:

```yaml
hello-world: Hallo Welt
```

6. Run your app with the new translation.

## Example 5 - ICU plurals, select, gender via `.trIcu()`:

For grammatically correct sentences across languages, use `.trIcu()` instead of `.tr()`. It expands the standard [ICU MessageFormat](https://unicode-org.github.io/icu/userguide/format_parse/messages/) syntax — plural, select, gender, and the CLDR plural rules — against the active locale.

```yaml
# assets/translations/en-us.yaml
cart-items: "{count, plural, =0{Cart is empty} one{# item} other{# items}}"
greet:      "{gender, select, male{Welcome, sir} female{Welcome, madam} other{Welcome}}"
hello:      "Hello, {name}!"
```

```yaml
# assets/translations/ru-ru.yaml — Russian has one/few/many plural forms
cart-items: "{count, plural, one{# товар} few{# товара} many{# товаров} other{# товара}}"
```

```dart
Text('cart-items'.trIcu(args: {'count': cart.length})); // -> "5 items"
Text('greet'.trIcu(args: {'gender': user.gender}));     // -> "Welcome, madam"
Text('hello'.trIcu(args: {'name': 'Robert'}));          // -> "Hello, Robert!"
```

CLDR plural rules are looked up by `ActiveLocale.current` — set automatically by every controller's `setLocale`. You can override per-call: `.trIcu(args: {...}, locale: const Locale('ru'))`.

## Example 6 - Flutter integration (`MaterialApp`, RTL):

Wire the translation locale into Flutter's standard i18n machinery — `Material*Localizations`, `Cupertino*Localizations`, `Directionality`, and the rest pick it up automatically.

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

MaterialApp(
  // The locale your controller is currently using.
  locale: AutoTranslationScope.localeOf(context),

  // What languages your app actually has translations for.
  supportedLocales: const [
    Locale('en', 'US'),
    Locale('de', 'DE'),
    Locale('ar', 'EG'),   // Arabic — Flutter swaps the whole UI to RTL.
    Locale('he', 'IL'),   // Hebrew — same.
  ],

  // Standard Flutter delegates. With these, MaterialApp handles
  // Directionality (RTL/LTR), date/time formatters, and the built-in
  // widget labels for you.
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],

  // Pick the best supported locale from the device's preferences.
  localeListResolutionCallback: (preferred, supported) =>
      bestLocale(supported, preferred: preferred),

  home: const MyHomePage(),
);
```

For RTL-aware code outside a `MaterialApp` (custom dialogs, error overlays, isolated tests), use `getTextDirection(locale)` or `isRtlLocale(locale)`:

```dart
Directionality(
  textDirection: getTextDirection(ActiveLocale.current),
  child: child,
);
```

## Example 7 - Server-driven translations (`RemoteTranslationController`):

When translations are produced server-side and the client just needs to fetch a flat key → string map per locale, use `RemoteTranslationController`. It drops the translator brokers and the `DatabaseInterface` cache — caching is the host fetcher's concern (wire it through your existing HTTP cache, `reliable`, etc.).

```dart
final controller = RemoteTranslationController(
  fetchTranslations: (locale) async {
    // Talk to your backend. Returns the flat key → string map.
    final res = await http.get(Uri.parse('https://api.example.com/i18n/${locale.toLanguageTag()}'));
    return (jsonDecode(res.body) as Map).cast<String, String>();
  },
);

await controller.init();             // resolves the persisted/platform locale
await controller.setLocale(const Locale('de', 'DE'));
'Hello||hello-world'.tr();           // returns whatever the server sent back
```

Stale-load protection is built in: rapid `setLocale` calls cannot let an older fetch's result overwrite a newer one.

<!-- END _README_CONTENT -->

---

🔍 For more information, refer to the [API reference](https://pub.dev/documentation/df_localization/).

---

## 💬 Contributing and Discussions

This is an open-source project, and we warmly welcome contributions from everyone, regardless of experience level. Whether you're a seasoned developer or just starting out, contributing to this project is a fantastic way to learn, share your knowledge, and make a meaningful impact on the community.

### ☝️ Ways you can contribute

- **Find us on Discord:** Feel free to ask questions and engage with the community here: https://discord.gg/gEQ8y2nfyX.
- **Share your ideas:** Every perspective matters, and your ideas can spark innovation.
- **Help others:** Engage with other users by offering advice, solutions, or troubleshooting assistance.
- **Report bugs:** Help us identify and fix issues to make the project more robust.
- **Suggest improvements or new features:** Your ideas can help shape the future of the project.
- **Help clarify documentation:** Good documentation is key to accessibility. You can make it easier for others to get started by improving or expanding our documentation.
- **Write articles:** Share your knowledge by writing tutorials, guides, or blog posts about your experiences with the project. It's a great way to contribute and help others learn.

No matter how you choose to contribute, your involvement is greatly appreciated and valued!

### ☕ We drink a lot of coffee...

If you're enjoying this package and find it valuable, consider showing your appreciation with a small donation. Every bit helps in supporting future development. You can donate here: https://www.buymeacoffee.com/dev_cetera

<a href="https://www.buymeacoffee.com/dev_cetera" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" height="40"></a>

## LICENSE

This project is released under the [MIT License](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE). See [LICENSE](https://raw.githubusercontent.com/dev-cetera/df_localization/main/LICENSE) for more information.
