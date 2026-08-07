# Changelog

## [0.7.3]

- chore: bump `df_config` to `^0.8.3`, which pins `df_string: ^0.4.0`. This carries df_string 0.4.0's case-conversion digit-boundary change (`phone_e164` instead of `phone_e_164`) through the shared `.tr()` engine. No df_localization API change.

## [0.7.2]

- fix: `String.trIcu` now guards the `MessageFormat` build/format in a try/catch. A malformed ICU template (a corrupt stored translation, or an author typo) previously threw `mismatched { or }` straight through to the host, greying every screen that rendered a plural. On failure it now forwards the error to `TranslationManager.reportError` and degrades gracefully: it formats the in-code source template (the part of the string before the `||key` delimiter, which the developer wrote) with the same args, falling back to the raw source only if that fails too — so a corrupt stored translation renders the source-language plural instead of crashing or showing broken ICU syntax. This matches `df_config`'s "a `.tr()` call must never crash the host" guarantee.
- fix: Bump `df_config` to `^0.8.2`, which stops the placeholder engine from corrupting inline ICU templates (`{count, plural, …}}`) during `.tr()`'s primary pass. Together these fix the greyed-screen crash when an ICU plural is rendered through a mapper-less `FileConfig` or before the first config install.

## [0.7.1]

- feat: Add **source-text translation versioning** to `AutoTranslationController` (`versionBySourceText`, default `true`). Translations are stored under `<key>@@<hash(sourceText)>`, so rewording a string in a new release adds a new entry instead of overwriting the one already-deployed builds read — a one-string change costs one entry, not a database snapshot. Fixing a bad translation (same source) still propagates to all builds. Lookups fall back to legacy plain-key entries whose stored `from` matches, so pre-versioning databases keep resolving; run `migrateToVersionedKeys(locales)` once to additively snapshot them. `RemoteTranslationController` gets the same flag (default `false`) for servers that key their maps with `versionedTranslationKey(key, sourceText)`.
- feat: The versioning helpers (`versionedTranslationKey`, `translationSourceHash`, `kTranslationVersionSeparator`) live in `df_config` ≥ 0.8.1 (pure Dart) and are re-exported here — Dart backends producing translation maps server-side can depend on `df_config` alone to key them. The hash is deterministic across platforms including web, and is pinned by a golden test.
- chore: Remove the `df_log` dependency — the runtime library never imported it, and the `gen-translations` CLI now prints with self-contained ANSI colors. Its `^0.5.1` constraint previously conflicted with hosts pinning newer `df_log` versions.

## [0.7.0]

- Tagged but never published (pub.dev validation failure); all changes shipped in 0.7.1.

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