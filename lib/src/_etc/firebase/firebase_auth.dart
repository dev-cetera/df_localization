import 'dart:convert';
import 'package:http/http.dart' as http;

class FirebaseAuth {
  const FirebaseAuth._();

  static FirebaseAuth? _instance;

  static FirebaseAuth get instance {
    _instance ??= const FirebaseAuth._();
    return _instance!;
  }

  Future<String> logInWithEmailAndPassword({
    required String email,
    required String password,
    required String apiKey,
  }) async {
    final uri = Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/accounts:signInWithPassword',
      {'key': apiKey},
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    return jsonDecode(response.body)['idToken'] as String;
  }
}