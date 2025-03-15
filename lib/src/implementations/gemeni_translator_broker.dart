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
class GeminiTranslatorBroker extends TranslatorInterface<GemeniContent> {
  //
  //
  //

  final String model;

  //
  //
  //

  const GeminiTranslatorBroker({
    required super.apiKey,
    this.model = 'gemini-1.5-flash-8b',
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
        _modelPrompt1(),
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
  Async<String> translate({required List<GemeniContent> contents}) {
    // See: https://aistudio.google.com/
    return Async(() async {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );
      final headers = {'Content-Type': 'application/json'};
      final prompt = {
        'contents': contents.map((content) => content.toJson()).toList(),
        'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1000},
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
          },
        ],
      };

      final response = await post(
        url,
        headers: headers,
        body: jsonEncode(prompt),
      );

      if (response.statusCode != 200) {
        throw Err(
          debugPath: ['GeminiTranslator', 'translate'],
          error: response.body,
          statusCode: response.statusCode,
        );
      }
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      final translatedText =
          responseData['candidates'][0]['content']['parts'][0]['text']
              as String;
      return translatedText;
    });
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

final class GemeniContent {
  final String role;
  final String text;

  const GemeniContent.user(this.text) : role = 'user';
  const GemeniContent.model(this.text) : role = 'model';

  Map<String, dynamic> toJson() => {
    'role': role,
    'parts': {'text': text},
  };
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

GemeniContent _modelPrompt1() {
  return const GemeniContent.model(
    'I am an app localization translator. I do not translate anything inside handlebars {{ }} or { } as these are parts that will be replaced in code. Moving forward I will not respond with any additional information other than the translation you request. Please provide your translation request.',
  );
}

GemeniContent _userPrompt1({
  required String text,
  required String languageCode,
  required String? countryCode,
}) {
  return GemeniContent.user(
    'Translate the following text to the language identified by the locale code "$languageCode"${countryCode != null ? ' with a strong focus on the country identified by the country code "$countryCode", ensuring the translation fully reflects the specific linguistic and cultural norms of that country' : ''}: "$text"',
  );
}
