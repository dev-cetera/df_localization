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

class FirestoreDatabseBroker extends DatabaseInterface {
  //
  //
  //

  final String projectId;
  final String? accessToken;

  //
  //
  //

  const FirestoreDatabseBroker({required this.projectId, this.accessToken});

  //
  //
  //

  @override
  Async<Map<String, dynamic>> read(String path) {
    return Async(() async {
      final uri = '$_baseUrl/$path';
      final url = Uri.parse(uri);
      final client = Client();
      final response = await client.get(url, headers: _authHeaders);
      if (response.statusCode != 200) {
        throw Err(
          debugPath: ['FirestoreStorage', 'readOrNull'],
          error: response.body,
          statusCode: response.statusCode,
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>;
      return convertToLocalJson(fields);
    });
  }

  //
  //
  //

  @override
  Async<None> write({
    required String path,
    required Map<String, dynamic> data,
  }) {
    return Async(() async {
      final segmentsResult = _getSegments(path);
      if (segmentsResult.isErr()) {
        throw segmentsResult;
      }
      final segments = segmentsResult.unwrap();
      final documentPath = segments.take(segments.length - 1).join('/');
      final documentId = segments.last;
      final uri = '$_baseUrl/$documentPath?documentId="$documentId"';
      final url = Uri.parse(uri);
      final body = jsonEncode({'fields': convertToFirestoreJson(data)});
      final client = Client();
      final response = await client.post(
        url,
        headers: _authHeaders,
        body: body,
      );
      if (response.statusCode != 200) {
        throw Err(
          debugPath: ['FirestoreStorage', 'write'],
          error: response.body,
          statusCode: response.statusCode,
        );
      }
      return const None();
    });
  }

  //
  //
  //

  @override
  Async<None> patch({
    required String path,
    required Map<String, dynamic> data,
  }) {
    return Async(() async {
      final segmentsResult = _getSegments(path);
      if (segmentsResult.isErr()) {
        throw segmentsResult;
      }
      final updateMask = data.keys
          .map((key) => 'updateMask.fieldPaths=$key')
          .join('&');
      final uri = '$_baseUrl/$path?$updateMask';
      final url = Uri.parse(uri);
      final body = jsonEncode({'fields': convertToFirestoreJson(data)});
      final client = Client();
      final response = await client.patch(
        url,
        headers: _authHeaders,
        body: body,
      );
      if (response.statusCode != 200) {
        throw Err(
          debugPath: ['FirestoreStorage', 'patch'],
          error: response.body,
          statusCode: response.statusCode,
        );
      }
      return const None();
    });
  }

  //
  //
  //

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  @pragma('vm:prefer-inline')
  Map<String, String> get _authHeaders => {
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Result<List<String>> _getSegments(String path) {
    final segments = path.split('/');
    if (segments.isEmpty || segments.length % 2 != 0) {
      return Err(
        debugPath: ['FirestoreStorage', '_getSegments'],
        error: 'path must have an even number of segments',
      );
    }
    return Ok(segments);
  }
}
