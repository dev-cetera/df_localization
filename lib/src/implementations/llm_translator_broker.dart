//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Copyright © dev-cetera.com & contributors.
//
// The use of this source code is governed by an MIT-style license described in
// the LICENSE file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Vendor-neutral LLM-backed translator. Pass any [AiBroker] (Anthropic,
/// Gemini, OpenAI, or a custom one) and this class drives it through the
/// same `AiMessage` / `ChatRequest` shape `ai_broker` already exposes — no
/// per-provider message-type clones.
///
/// For the three common providers use the named factory constructors
/// ([LlmTranslatorBroker.claude], [LlmTranslatorBroker.gemini],
/// [LlmTranslatorBroker.openai]) which pre-fill a sensible default model.
class LlmTranslatorBroker extends TranslatorInterface<AiMessage> {
  /// The underlying provider. Owns the HTTP call; this class only owns
  /// the prompt shape and the `df_safer_dart` error wrapping.
  final AiBroker broker;

  /// Provider-specific model id, e.g. `'claude-3-haiku-20240307'`,
  /// `'gemini-1.5-flash-8b'`, `'gpt-4o-mini'`.
  final String model;

  /// System instruction sent on every call. Defaults to a prompt that
  /// tells the model to act as an app-localization translator and to
  /// leave `{...}` / `{{...}}` placeholders untouched.
  final String systemPrompt;

  /// Sampling temperature. Defaults to `0.2` — translation should be
  /// near-deterministic.
  final double temperature;

  /// Output ceiling. Defaults to `1000`.
  final int maxTokens;

  const LlmTranslatorBroker({
    required super.apiKey,
    required this.broker,
    required this.model,
    this.systemPrompt = defaultSystemPrompt,
    this.temperature = 0.2,
    this.maxTokens = 1000,
  }) : assert(apiKey != null);

  /// Anthropic Claude. Default model is the cheapest stable Haiku tier.
  factory LlmTranslatorBroker.claude({
    required String apiKey,
    String model = 'claude-3-haiku-20240307',
    String systemPrompt = defaultSystemPrompt,
    double temperature = 0.2,
    int maxTokens = 1000,
    AiBroker? broker,
  }) =>
      LlmTranslatorBroker(
        apiKey: apiKey,
        broker: broker ?? AnthropicBroker(),
        model: model,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
      );

  /// Google Gemini. Default model is the lightweight 8B Flash tier.
  factory LlmTranslatorBroker.gemini({
    required String apiKey,
    String model = 'gemini-1.5-flash-8b',
    String systemPrompt = defaultSystemPrompt,
    double temperature = 0.2,
    int maxTokens = 1000,
    AiBroker? broker,
  }) =>
      LlmTranslatorBroker(
        apiKey: apiKey,
        broker: broker ?? GeminiBroker(),
        model: model,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
      );

  /// OpenAI. Default model is the cheap, fast 4o-mini tier.
  factory LlmTranslatorBroker.openai({
    required String apiKey,
    String model = 'gpt-4o-mini',
    String systemPrompt = defaultSystemPrompt,
    double temperature = 0.2,
    int maxTokens = 1000,
    AiBroker? broker,
  }) =>
      LlmTranslatorBroker(
        apiKey: apiKey,
        broker: broker ?? OpenAiBroker(),
        model: model,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
      );

  @override
  Async<String> translateSentence({
    required String text,
    required String languageCode,
    required String? countryCode,
  }) {
    return translate(
      contents: [_buildUserMessage(text, languageCode, countryCode)],
    );
  }

  @override
  Async<String> translate({required List<AiMessage> contents}) {
    return Async(() async {
      try {
        return await broker.chat(
          apiKey: apiKey!,
          model: model,
          request: ChatRequest(
            system: systemPrompt,
            messages: contents,
            temperature: temperature,
            maxTokens: maxTokens,
          ),
        );
      } on AiBrokerException catch (e) {
        // Preserve the HTTP status so callers can distinguish auth /
        // rate-limit / server failures.
        throw Err(e.message, statusCode: e.statusCode);
      }
    });
  }

  /// Default system instruction. Exposed so callers can prepend extra
  /// guidance (`'$defaultSystemPrompt\nAlways prefer formal address.'`)
  /// without losing the placeholder rule.
  static const String defaultSystemPrompt =
      'You are an app localization translator. You do not translate '
      'anything inside handlebars {{ }} or { } as these are parts that '
      'will be replaced in code. You do not respond with any additional '
      'information other than the translation.';
}

AiMessage _buildUserMessage(
  String text,
  String languageCode,
  String? countryCode,
) {
  final country = countryCode == null
      ? ''
      : ' with a strong focus on the country identified by the country '
          'code "$countryCode", ensuring the translation fully reflects '
          'the specific linguistic and cultural norms of that country';
  return AiMessage.user(
    'Translate the following text to the language identified by the locale '
    'code "$languageCode"$country: "$text"',
  );
}
