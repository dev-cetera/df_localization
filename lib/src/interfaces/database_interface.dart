import 'package:df_safer_dart/df_safer_dart.dart';

abstract class DatabaseInterface {
  const DatabaseInterface();

  Async<Map<String, dynamic>> read(String path);

  Async<None> write({
    required String path,
    required Map<String, dynamic> data,
  });

  Async<None> patch({
    required String path,
    required Map<String, dynamic> data,
  });
}
