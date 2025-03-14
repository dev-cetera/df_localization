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

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class OpenAITranslatorBrokerC1 extends TranslatorInterface {
  //
  //
  //

  const OpenAITranslatorBrokerC1({
    required super.apiKey,
  }) : assert(apiKey != null);

  //
  //
  //

  @override
  Async<String> translate({
    required String text,
    required String languageCode,
    required String? countryCode,
  }) {
    return Async(() async {
      final url = Uri.parse(
        'https://api.openai.com/v1/chat/completions',
      );
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };
      final body = jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an app localization translator. You do not translate anything inside handlebars {{ }} or { } as these are parts that will be replaced in code. You do not respond with any additional information other than the translation.',
          },
          {
            'role': 'user',
            'content':
                'Translate the following text to the language identified by the locale code "$languageCode"${countryCode != null ? 'with a strong focus on the country identified by the country code "$countryCode", ensuring the translation fully reflects the specific linguistic and cultural norms of that country' : ''}: "$text"',
          },
        ],
        'temperature': 0.7,
      });

      final response = await post(
        url,
        headers: headers,
        body: body,
      );
      if (response.statusCode != 200) {
        throw Err(
          debugPath: ['OpenAITranslator', 'translate'],
          error: response.body,
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      )['choices'][0]['message']['content'] as String;
    });
  }
}
