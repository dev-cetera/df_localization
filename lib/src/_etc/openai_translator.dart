import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAITranslator {
  const OpenAITranslator._();

  static OpenAITranslator? _instance;

  static OpenAITranslator get instance {
    _instance ??= const OpenAITranslator._();
    return _instance!;
  }

  Future<String?> translate({
    required String text,
    required String languageCode,
    required String countryCode,
    required String apiKey,
    String baseUrl = 'https://api.openai.com/v1',
    String model = 'gpt-3.5-turbo',
    Iterable<String> historyContent = const [],
    String systemInstruction =
        'You are an app localization translator. You do not translate anything inside handlebars {{ }} or { } as these are parts that will be replaced in code. You do not respond with any additional information other than the translation.',
  }) async {
    final url = Uri.parse('$baseUrl/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        ...historyContent.map((e) => {'role': 'user', 'content': e}),
        {
          'role': 'user',
          'content':
              'Translate the following text to the language "$languageCode" with a strong focus on the country "$countryCode", ensuring the translation fully reflects the specific linguistic and cultural norms of that country: "$text"',
        },
      ],
      'temperature': 0.7,
    });

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body)['choices'][0]['message']['content']
        as String;
  }
}
