# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The workspace-level `df_packages/CLAUDE.md` covers the umbrella-repo shape, cross-package wiring, the `@scripts/` PowerShell helpers, the lint baseline, and the release flow. This file only documents what is specific to `df_localization`.

## What this package actually is

A localization runtime for Flutter apps built around the `.tr()` string extension from `df_config`. `.tr()` dispatches through `TranslationManager.config` — a `FileConfig` whose `mapper` callback decides what string to return for a given key. **All three controllers in this package work by installing their own `FileConfig` on `TranslationManager.config`.** That mapper is the single integration point — everything else (locale persistence, caching, network calls, debouncing) is bookkeeping around it.

### Key format used by `.tr()`

- `'Some text||some-key'.tr()` — `||` separates the default English text from the translation key. The key is optional; without `||`, the default text doubles as the key.
- `'Hello {__NAME__}'.tr(args: {'__NAME__': 'Robert'})` — placeholders are `{...}`. The double-underscore convention (`__NAME__`) exists so Google Translate leaves the token alone when auto-translating sentences.

### `.tr()` vs `.trIcu()`

Two extensions ship side by side:

- **`.tr()`** (from `df_config`) — flat key/value lookup plus naive `{name}` placeholder substitution via `df_config`'s primary + secondary pattern passes. Use it for everything that doesn't need plurals.
- **`.trIcu({args, preferKey, locale})`** (this package, `lib/src/icu/tr_icu_extension.dart`) — looks up the same template the mapper would return, then runs it through `intl`'s [`MessageFormat`](https://pub.dev/documentation/intl/latest/message_format/MessageFormat-class.html). Supports the full ICU subset: `plural`, `select`, `selectordinal`, simple `{name}` placeholders, and `#` inside plural branches. Locale comes from `ActiveLocale.current` unless explicitly overridden.

Implementation detail to preserve: `.trIcu()` calls `.tr(secondarySettings: null)` to skip the `df_config` second-pass placeholder substitution — otherwise it would mangle the ICU braces before `MessageFormat` ever sees them. If you change that, ICU patterns will break in subtle ways. Covered by the `ICU plural / select expansion via .trIcu()` tests.

## The three controllers — pick the right one

All three live in `lib/src/` and are mutually exclusive at runtime (the last `init`/`setLocale` wins because they share `TranslationManager.config`).

| Controller | Source of translations | When to use |
| --- | --- | --- |
| `TranslationController` | Static asset files (`assets/translations/en-us.yaml` etc.) loaded via `rootBundle`. Singleton (`TranslationController.i` after `createInstance`). | Ship-with-the-app translations, fully offline. |
| `AutoTranslationController` | Three pluggable brokers: a `TRemoteDatabaseInterface` (e.g. Firestore), an optional `TCachedDatabaseInterface` (e.g. SharedPreferences), and an optional `TTranslationInterface` (Google Translate or `LlmTranslatorBroker`). In debug mode missing keys get auto-translated and written back to both databases; in release the translator is normally off and the app just reads the database. | Apps where you want copy to translate itself the first time it's rendered in dev, then freeze that as data for production. |
| `RemoteTranslationController` | A single `Future<Map<String, String>> Function(Locale)` callback. No translator broker, no `DatabaseInterface` cache — caching is the host's problem (wire it through `reliable` or similar). | Apps where translations are produced server-side and the client just fetches a flat map per locale. |

`AutoTranslationScope` is the `InheritedWidget` wrapper for `AutoTranslationController`; the other two have no widget and are driven directly. Reach the active controller via `AutoTranslationScope.controllerOf(context)` / `.localeOf(context)`.

## How `df_config` is used

`df_config` ≥ **0.8.1** is the contract. The relevant surface:

- **`TranslationManager`** is `abstract final class` — *static only*. Do **not** try to `new TranslationManager()`; it won't compile.
- Install a config with `await TranslationManager.setConfig(fileConfig)`. It returns `Future<FileConfig>`, internally serialises writes on a `_writeChain` so rapid `setLocale` calls cannot leave the active config half-written. **Always await it** — otherwise callers that hit `.tr()` synchronously after will see the previous mapper.
- Read with `TranslationManager.config` — cheap synchronous getter.
- For tests, call `TranslationManager.resetForTesting()` in `setUp`; otherwise the static `_active` config leaks between tests.
- For safety-critical apps, set `TranslationManager.onError = (source, error, stack) => ...` to capture errors that `.tr()` and `setConfig` would otherwise swallow. We do not set this from within `df_localization`; it's a hook for the host app.
- The mapper signature is `dynamic Function(TGetKeyAndDefaultValueResult textResult)` where `TGetKeyAndDefaultValueResult` is a record `({String key, String defaultValue})`. Access with `textResult.key` / `textResult.defaultValue`.

`FileConfig` constructors used here are mapper-only (`FileConfig(mapper: ...)`, no `ref`), so `setConfig`'s internal `readAssociatedFile` is a no-op. The file-loading path is the asset-based `TranslationController`, which routes through `TranslationFileReader.read(...)` — that helper builds a `FileConfig` *with* a `ConfigFileRef` and calls `TranslationManager.setConfig` for you.

## Important implementation details (don't regress these)

- **Stale-load protection** in both `AutoTranslationController` and `RemoteTranslationController`: each `setLocale` bumps `_activeRequestId`; in-flight async loads check it before writing to `_pCache`. Dropping this causes the wrong locale's data to land in the cache when the user toggles quickly.

- **Stale-locale protection inside `_translateAndUpdate`** (auto-translate path): the mapper closes over `requestId` and `activeLocale` *at the time it fires* and passes them into `_translateAndUpdate`. After the translation `await` returns, the function bails if `requestId != _activeRequestId` — without this, a de-translation that resolves *after* the user switched to fr writes a de string into the fr cache and patches it onto the fr DB path. Covered by the `stale-locale guard` test.

- **Per-key translate dedupe** in `AutoTranslationController._didRequestTranslate`: each missing key fires exactly one translation request per locale, regardless of how many `.tr()` calls reference it on first frame. Reset on every `setLocale`. **Do not reintroduce a global `Throttle`** around `_translateAndUpdate` — a prior version did, and it dropped every key but one during the first-frame burst.

- **`_pCache` updates must build a new map, not mutate in place.** `setLocale`'s fallback for "no remote translations yet" is `const <String, TranslatedText>{}` — *unmodifiable*. Using `_pCache.update((e) => e..[key] = x)` against that crashes with `Cannot modify unmodifiable map`. The correct pattern is `_pCache.update((e) => {...e, key: x})`. Covered by the `AI translates → in-memory cache + remote DB + persistent DB` test.

- **`TranslationController.setLocale` awaits the file read.** Returning early would race `.tr()` calls fired immediately after. The bootstrap path (loading a persisted locale at app start) still goes through the pod's `fromValue` callback, which fires `_readSafely(...).ignore()` — that one is fire-and-forget because nothing is awaiting it. Do not also fire `_read` from `toValue`; `setLocale` already awaits explicitly there.

- **`TranslatedText` shape** stored in the database: `{to, from}`. `from` is the original default text. Besides staleness detection, `from` is now load-bearing for **source-text versioning** (below): the stored key's hash is derived from it, and the legacy-plain-key fallback only fires when `from` matches the rendered copy. `RemoteTranslationController` deliberately uses a flat `Map<String, String>` instead (the server is responsible for staleness/versioning).

- **Source-text versioning** (`AutoTranslationController`, `versionBySourceText` — default `true`): translations are stored under `<key>@@<hash(source)>`, not the plain `<key>`. The helpers (`versionedTranslationKey` / `translationSourceHash` / `kTranslationVersionSeparator`) live in **`df_config`** (`lib/src/support/versioned_translation_key.dart` there) — deliberately, so pure-Dart backends can key server-side maps without depending on this Flutter package; they reach consumers here via the wholesale `df_config` re-export. This is how an already-deployed build keeps reading the exact translation it shipped against: a newer build that edits a string writes a *new* entry under a new hash instead of overwriting the shared one, so a one-string change costs one new entry, not a copy of the DB. **Invariants not to regress:**
  - The write path (`_translateAndUpdate`) and the read path (`_installConfig`'s mapper) must key by the *same* composite (`storageKey`). The mapper passes `storageKey` (not the plain key) into `_translateAndUpdate`, and `TranslatedText.from` is set to the source so `hash(from)` equals the hash embedded in the key.
  - The mapper's **legacy fallback** reads a plain-`<key>` entry only when `legacy.from == source`. It is read-only — never write back under the plain key, or you reintroduce the shared-overwrite bug. Covered by the `legacy fallback` test.
  - `translationSourceHash` must stay **deterministic across platforms including web** — it uses `< 2^53` integer math on purpose (no `String.hashCode`, no 64-bit bitwise ops). Changing the algorithm silently orphans every existing entry.
  - `migrateToVersionedKeys(locales)` is **additive and idempotent**: it *adds* `<key>@@<hash(from)>` alongside the existing plain key (never deletes it, so old builds keep resolving) and skips entries already versioned/migrated. Covered by the `migrateToVersionedKeys` test.
  - `RemoteTranslationController` has the same flag (default **`false`**, host-owned): when `true` it looks up `versionedTranslationKey(key, source)` before the plain key, so a server that keys its map with the same helper pins each build to its shipped copy.

- **`init()` is idempotent** on `AutoTranslationController` / `RemoteTranslationController` — concurrent callers share `_initFuture`. `AutoTranslationScope` calls it in `initState`.

- **Locale persistence** uses `SharedPod<Locale, String>` from `df_pod` under `cacheKey` (default `'locale'`). Serialization goes through `getNormalizedLanguageTag` / `localeFromString` in `lib/src/utils/`. If you change either side, change both.

## Translator brokers

`TranslatorInterface<T>` (`lib/src/interfaces/translator_interface.dart`) returns `Async<...>` from `df_safer_dart`, **not** raw `Future`s. New brokers must follow that convention: `Async<String> translateSentence(...)` and `Async<String> translate({required List<T> contents})`.

Implementations shipped:

- **`GoogleTranslatorBroker`** — direct REST call to the Google Translate v2 API. Cheapest option for short UI strings.
- **`LlmTranslatorBroker`** — the unified LLM broker. Backed by any `AiBroker` from `ai_broker`. Use the named factories:
  - `LlmTranslatorBroker.claude(apiKey: ...)` — defaults to `claude-3-haiku-20240307`.
  - `LlmTranslatorBroker.gemini(apiKey: ...)` — defaults to `gemini-1.5-flash-8b`.
  - `LlmTranslatorBroker.openai(apiKey: ...)` — defaults to `gpt-4o-mini`.
  - `LlmTranslatorBroker(broker: SomeFutureBroker(), apiKey: ..., model: ...)` — for any provider not in the list above.

Per-vendor message-type clones (`ClaudeContent` / `GeminiContent` / `OpenAIContent`) were deleted — `LlmTranslatorBroker` uses `AiMessage` directly. If you need provider-specific behaviour, configure the `systemPrompt` / `temperature` / `maxTokens` parameters or subclass.

The `AiBroker` and friends (`AnthropicBroker`, `GeminiBroker`, `OpenAiBroker`, `AiMessage`, `ChatRequest`, `AiBrokerException`) are re-exported from `_common.dart` — depend on those rather than re-importing `package:ai_broker` directly inside this package's `lib/src/`.

## Database brokers

`DatabaseInterface` (`lib/src/interfaces/database_interface.dart`) is three `Async`-returning methods: `read(path)`, `write({path, data})`, `patch({path, data})`. Implementations: `FirestoreDatabseBroker` (remote — Firestore REST) and `PersistentDatabaseBroker` (local — SharedPreferences).

## Project-specific conventions

- **`lib/_common.dart`** is the internal umbrella. Sources import it as `'/_common.dart'` (root-relative — possible because `prefer_relative_imports` is enforced and the analyzer treats it as relative to the package's `lib/`). Add new ambient deps here, not per-file. It re-exports `df_config`, `df_pod`, `df_safer_dart`, `df_debouncer`, `http`, `dart:convert`, and the named `ai_broker` symbols.
- **`lib/df_localization.dart`** is the public library — narrower than `_common.dart`. It exports `df_config`, `df_pod`, `df_safer_dart` (so consumers get `.tr()` and pods transitively) but **not** `http`, `dart:convert`, `df_debouncer`, or `ai_broker`. Keep that asymmetry — those are implementation details.
- **`lib/src/_src.g.dart`** is generated by `df_generate_dart_indexes`. Do not hand-edit. Adding a new file under `lib/src/` requires regenerating this barrel (or hand-add the export and let the next regeneration confirm).
- **Known intentional misspellings** — do not "fix" them as drive-bys:
  - Class `FirestoreDatabseBroker` (missing `a`) — public, used by consumers.
  - Typedef `TTransaltionMap` — `@Deprecated`, kept for one minor cycle. New code uses `TTranslationMap`.

## Locale-aware helpers and Flutter integration

All locale utilities live in `lib/src/utils/` (plus `lib/src/active_locale.dart`). They're designed to slot into Flutter's standard i18n machinery rather than replace it.

- **`ActiveLocale`** (`lib/src/active_locale.dart`) — process-wide static holder of the currently active locale. Updated by every controller's `setLocale` (search for `ActiveLocale.set` to find the three call sites). Read by `.trIcu()` for CLDR plural rules and by anything that needs the current locale without depending on a specific controller. Falls back to the platform locale when no controller has set it. `ActiveLocale.resetForTesting()` is the test seam — must be called from `setUp` alongside `TranslationManager.resetForTesting()`.

- **`getSystemLocale()` / `getSystemLocales()`** (`lib/src/utils/get_system_locale.dart`) — wrap `WidgetsBinding.instance.platformDispatcher.locale[s]`. Work uniformly on iOS, Android, macOS, Windows, Linux, and Web because Flutter normalises the lookup behind `PlatformDispatcher`. Prefer these over the raw accessor — they're the documented public surface and are easy to mock in tests.

- **`bestLocale(supported, {preferred})`** (`lib/src/utils/best_locale.dart`) — picks the best supported locale from the device's preferences. Designed to drop straight into `MaterialApp.localeListResolutionCallback`. Priority: exact (language + country) → language-only → first of `supported`. Empty `supported` falls back to `getSystemLocale()`.

- **`isRtlLocale(locale)` / `getTextDirection(locale)`** (`lib/src/utils/is_rtl_locale.dart`) — RTL detection via `intl`'s `Bidi.isRtlLanguage` (canonical Unicode RTL script list). Use `getTextDirection` to drive a `Directionality` widget outside a `MaterialApp` (custom dialogs, error overlays). Inside a `MaterialApp` the framework already wires this via `GlobalWidgetsLocalizations`, so don't double-wrap.

### Standard Flutter i18n wiring

When a host app uses this package alongside Flutter's stock i18n:

1. `MaterialApp.locale = AutoTranslationScope.localeOf(context)` (or a `ValueListenableBuilder` on `TranslationController.i.pLocale`) — pipes the active locale into Flutter's `Localizations` so `MaterialLocalizations`, `CupertinoLocalizations`, etc. resolve correctly.
2. `MaterialApp.localizationsDelegates: [GlobalMaterialLocalizations.delegate, ...]` — Flutter handles RTL `Directionality` automatically; we don't need our own delegate for that.
3. `MaterialApp.localeListResolutionCallback: (pref, sup) => bestLocale(sup, preferred: pref)` — when the user's device language changes, Flutter calls this with the platform's preferred list and we pick from the app's `supportedLocales`.
4. `MaterialApp.supportedLocales` should mirror the locales for which translations actually exist on disk / in the remote DB.

We deliberately do NOT ship a `LocalizationsDelegate` — every controller is already global state via `TranslationManager`, so being in the delegate chain would add ceremony without benefit. If a host wants their own delegate to observe locale changes, they can write a one-class wrapper themselves.

## CLI tool

The `bin/gen_translations.dart` script greps a Flutter project for `.tr()` calls and asks any LLM to translate them, writing the result as a YAML/JSON file. Exposed via `pubspec.yaml` as `gen-translations: gen_translations`. The bin folder has its own minimal `pubspec.yaml` that declares `ai_broker` (and intentionally **not** `df_safer_dart` — the bin tool stays on raw `Future`s).

Activate and run:

```sh
dart pub global activate df_localization
gen-translations --provider claude --locale "de-de" --api_key "..." --output "assets/translations"
```

`--provider` accepts `claude`, `gemini`, `openai`; per-provider default model is used if `--model` is omitted. Defaults: `--root` = cwd, `--type` = yaml.

## Tests

`test/auto_translation_flow_test.dart` covers the end-to-end auto-translate flow against the `AutoTranslationController`:
1. AI translates → in-memory cache + remote DB + persistent DB.
2. Release mode — a fresh controller loads from a pre-populated remote DB.
3. Stale-locale guard — a de-translation that resolves after a switch to fr does not poison the fr cache.
4. Translator failure — no DB writes, cache untouched, key not retried.

`test/translation_controller_test.dart` covers the file-based `TranslationController` and the system-locale helpers.

`test/icu_and_locale_test.dart` covers ICU expansion (English / Russian plurals, select on gender, simple placeholders, per-call locale override), RTL detection across Arabic / Hebrew / Persian / Urdu, `bestLocale` priority order, and that every controller's `setLocale` updates `ActiveLocale`.

Test boilerplate that must be in every test file in this package:
- `TestWidgetsFlutterBinding.ensureInitialized()` at the top of `main()` (needed for `WidgetsBinding.instance.platformDispatcher` and the SharedPreferences plugin stub).
- In `setUp`: `SharedPreferences.setMockInitialValues({})`, `TranslationManager.resetForTesting()`, and `ActiveLocale.resetForTesting()`. Without these, the static `_active` config and `ActiveLocale._current` leak between tests and the wrong mapper / locale fires.
- The broker-based controllers are tested by injecting fake `DatabaseInterface` / `TranslatorInterface` implementations. `TranslationController.setReader` is `@visibleForTesting` and is the intended seam for the file-based controller — pass a fake `TranslationFileReader` whose `fileReader` returns an in-memory string.
- Use `Completer<void>` as a "gate" on a fake translator to interleave a `setLocale` between request and response (see the stale-locale guard test for the pattern).
- Note that `TranslationController._readSafely` calls `assert(false, ...)` on read failure. Fake `fileReader`s in tests must return **valid YAML** (at minimum a non-null mapping like `'placeholder: ""\n'`) — otherwise the debug-mode assertion fires even if you don't care about the file content.

## Release

`./deploy.sh` merges `main` into `prod` and pushes `prod`, which triggers `.github/workflows/prod.yml` to publish to pub.dev. The standard `+message` / `++message` commit-prefix flow from the workspace CLAUDE.md also works on `main`.
