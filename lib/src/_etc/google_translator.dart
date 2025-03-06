import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleTranslator {
  const GoogleTranslator._();

  static GoogleTranslator? _instance;

  static GoogleTranslator get instance {
    _instance ??= const GoogleTranslator._();
    return _instance!;
  }

  Future<String?> translate({
    required String text,
    required String languageCode,
    required String countryCode,
    required String apiKey,
  }) async {
    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$apiKey',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'target': languageCode,
        'format': 'text',
      }),
    );
    return jsonDecode(
      utf8.decode(response.bodyBytes),
    )?['data']?['translations']?[0]?['translatedText'] as String?;
  }
}
