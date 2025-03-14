import 'package:df_safer_dart/df_safer_dart.dart';

abstract class TranslatorInterface {
  final String? apiKey;

  const TranslatorInterface({this.apiKey});

  Async<String> translate({
    required String text,
    required String languageCode,
    required String? countryCode,
  });
}
