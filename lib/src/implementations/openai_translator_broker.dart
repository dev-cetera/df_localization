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

class OpenAITranslatorBroker extends TranslatorInterface<OpenAIContent> {
  //
  //
  //

  final String model;

  //
  //
  //

  const OpenAITranslatorBroker({
    required super.apiKey,
    this.model = 'gpt-3.5-turbo',
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
  Async<String> translate({required List<OpenAIContent> contents}) {
    return Async(() async {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };
      final body = jsonEncode({
        'model': model,
        'messages': contents.map((content) => content.toJson()).toList(),
        'temperature': 0.7,
      });

      final response = await post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Err(response.body, statusCode: response.statusCode);
      }
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      )['choices'][0]['message']['content'] as String;
    });
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

final class OpenAIContent {
  final String role;
  final String content;

  const OpenAIContent.system(this.content) : role = 'system';
  const OpenAIContent.user(this.content) : role = 'user';
  const OpenAIContent.assistant(this.content) : role = 'assistant';

  Map<String, String> toJson() => {'role': role, 'content': content};
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

OpenAIContent _systemPrompt1() {
  return const OpenAIContent.system(
    'You are an app localization translator. You do not translate anything inside handlebars {{ }} or { } as these are parts that will be replaced in code. You do not respond with any additional information other than the translation.',
  );
}

OpenAIContent _userPrompt1({
  required String text,
  required String languageCode,
  required String? countryCode,
}) {
  return OpenAIContent.user(
    'Translate the following text to the language identified by the locale code "$languageCode"${countryCode != null ? 'with a strong focus on the country identified by the country code "$countryCode", ensuring the translation fully reflects the specific linguistic and cultural norms of that country' : ''}: "$text"',
  );
}
