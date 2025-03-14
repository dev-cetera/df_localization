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

class GoogleTranslatorBroker extends TranslatorInterface {
  //
  //
  //

  const GoogleTranslatorBroker({
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
        'https://translation.googleapis.com/language/translate/v2?key=$apiKey',
      );
      final response = await post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'target': languageCode,
          'format': 'text',
        }),
      );
      if (response.statusCode != 200) {
        throw Err(
          debugPath: ['GoogleTranslator', 'translate'],
          error: response.body,
          statusCode: response.statusCode,
        );
      }
      final result = jsonDecode(
        utf8.decode(response.bodyBytes),
      )?['data']?['translations']?[0]?['translatedText'] as String;
      return result;
    });
  }
}
