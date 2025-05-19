//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Dart/Flutter (DF) Packages by dev-cetera.com & contributors. The use of this
// source code is governed by an MIT-style license described in the LICENSE
// file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import 'package:flutter/foundation.dart' show visibleForTesting;

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

@visibleForTesting
class ClaudeTranslatorBroker extends TranslatorInterface<ClaudeContent> {
  //
  //
  //

  final String model;

  //
  //
  //

  const ClaudeTranslatorBroker({
    required super.apiKey,
    this.model = 'claude-3-haiku-20240307',
  }) : assert(apiKey != null);

  //
  //
  //

  @override
  Async<String> translateSentence({
    required String text,
    required String languageCode,
    required String? countryCode,
  }) {
    return translate(
      contents: [
        _systemPrompt1(),
        _userPrompt1(
          text: text,
          languageCode: languageCode,
          countryCode: countryCode,
        ),
      ],
    );
  }

  //
  //
  //

  @override
  Async<String> translate({required List<ClaudeContent> contents}) {
    return Async(() async {
      final url = Uri.parse('https://api.anthropic.com/v1/messages');
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': apiKey!,
        'anthropic-version': '2023-06-01',
      };

      final body = jsonEncode({
        'model': model,
        'max_tokens': 1000,
        'temperature': 0.2,
        'messages': contents.map((content) => content.toJson()).toList(),
      });

      final response = await post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Err(
          response.body,
          statusCode: response.statusCode,
        );
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      final translatedText = responseData['content'][0]['text'] as String;

      return translatedText;
    });
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

final class ClaudeContent {
  final String role;
  final String content;

  const ClaudeContent.system(this.content) : role = 'system';
  const ClaudeContent.user(this.content) : role = 'user';
  const ClaudeContent.assistant(this.content) : role = 'assistant';

  Map<String, String> toJson() => {'role': role, 'content': content};
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

ClaudeContent _systemPrompt1() {
  return const ClaudeContent.system(
    'You are an app localization translator. You do not translate anything inside handlebars {{ }} or { } as these are parts that will be replaced in code. You do not respond with any additional information other than the translation.',
  );
}

ClaudeContent _userPrompt1({
  required String text,
  required String languageCode,
  required String? countryCode,
}) {
  return ClaudeContent.user(
    'Translate the following text to the language identified by the locale code "$languageCode"${countryCode != null ? 'with a strong focus on the country identified by the country code "$countryCode", ensuring the translation fully reflects the specific linguistic and cultural norms of that country' : ''}: "$text"',
  );
}
