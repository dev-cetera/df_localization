# Changelog

## [0.6.0]

- breaking: Remove `ClaudeTranslatorBroker`, `GeminiTranslatorBroker`, `OpenAITranslatorBroker` — replaced by the unified `LlmTranslatorBroker` with `.claude()` / `.gemini()` / `.openai()` factory constructors that drive any `AiBroker` from `ai_broker`.
- breaking: Rename the `gen-translations-gemini` CLI to `gen-translations`. Adds a `--provider claude|gemini|openai` flag and drops the `google_generative_ai` dependency in favour of `ai_broker`.
- breaking: Bump `df_config` to `^0.8.0`. Code that previously assigned `TranslationManager.config = ...` must switch to `await TranslationManager.setConfig(...)`.
- feat: Add `RemoteTranslationController` for apps where translations are fetched from a backend via a single `Future<Map<String, String>> Function(Locale)` callback. Includes built-in stale-load protection for rapid locale switches.
- feat: Add `.trIcu({args, preferKey, locale})` extension — full ICU MessageFormat support (plural, select, gender, `selectordinal`) with CLDR rules per locale, backed by `intl`'s `MessageFormat`.
- feat: Add `getSystemLocale()` / `getSystemLocales()` / `bestLocale(supported, {preferred})` — cross-platform locale helpers (iOS, Android, macOS, Windows, Linux, Web). `bestLocale` is a drop-in for `MaterialApp.localeListResolutionCallback`.
- feat: Add `isRtlLocale(locale)` / `getTextDirection(locale)` helpers for right-to-left languages.
- feat: Add `ActiveLocale` — process-wide active locale read by `.trIcu()` for plural rules and updated automatically by every controller's `setLocale`.
- fix: `AutoTranslationController` no longer poisons the new-locale cache or DB path when the user switches locale mid-translation.
- fix: First auto-translation against an empty remote database no longer crashes with `Cannot modify unmodifiable map`.
- fix: `TranslationController.setLocale` now awaits the file read so `.tr()` calls fired immediately after are guaranteed to see the new translations.
- fix: `TranslationController.createInstance` accepts the `fileType` parameter documented in the README.