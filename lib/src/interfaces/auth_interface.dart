import 'package:df_safer_dart/df_safer_dart.dart';

abstract class AuthInterface {
  final String? apiKey;

  const AuthInterface({this.apiKey});

  Async<LoginResult> logInWithEmailAndPassword({
    required String email,
    required String password,
  });
}

final class LoginResult {
  final String? idToken;

  const LoginResult({this.idToken});
}
