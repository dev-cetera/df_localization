import 'package:http/http.dart' as http;
import 'dart:convert';

import 'convert_to_firestore.dart';
import 'convert_to_local.dart';

class FirestoreStorage {
  //
  //
  //

  final String projectId;
  final String? accessToken;
  final http.Client _httpClient = http.Client();

  //
  //
  //

  FirestoreStorage({
    required this.projectId,
    this.accessToken,
  });

  //
  //
  //

  String _getBaseURL() =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  //
  //
  //

  @pragma('vm:prefer-inline')
  Map<String, String> get _authHeaders => {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  //
  //
  //

  Future<Map<String, dynamic>?> read(String path) async {
    try {
      final url = Uri.parse('${_getBaseURL()}/$path');
      final response = await _httpClient.get(url, headers: _authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final fields = data['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          return convertToLocalJson(fields);
        }
      }
      return null;
    } catch (e) {
      print('ERROR: $e');
      return null;
    }
  }

  //
  //
  //

  Future<void> write({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse(
      '${_getBaseURL()}/$collectionPath?documentId="$documentId"',
    );
    await _httpClient.post(
      url,
      headers: _authHeaders,
      body: jsonEncode({'fields': convertToFirestoreJson(data)}),
    );
  }

  //
  //
  //

  Future<http.Response> patch({
    required String documentPath,
    required Map<String, dynamic> data,
  }) async {
    final updateMask =
        data.keys.map((key) => 'updateMask.fieldPaths=$key').join('&');
    final url = Uri.parse('${_getBaseURL()}/$documentPath?$updateMask');
    final response = await _httpClient.patch(
      url,
      headers: _authHeaders,
      body: jsonEncode({'fields': convertToFirestoreJson(data)}),
    );
    return response;
  }
}
