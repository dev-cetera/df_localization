// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';

import 'package:df_config/_common.dart';
import 'package:df_config/df_config.dart';
import 'package:df_pod/df_pod.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

final pCache = Pod<Map<String, String>>({});

void main() async {
  final idToken = await login(
    'robmllze@gmail.com',
    'Testing123',
    'AIzaSyAFElkmkKgn-5WOIegFtrSm3lRqtN4ajLA',
  );
  print(idToken);

  String locale = 'af-za';

  var box = await Hive.openBox<String>(locale);

  final firestore = Firestore(projectId: 'langchapp', accessToken: idToken);
  final remoteFields = await firestore.read('translations/$locale');

  if (remoteFields != null) {
    pCache.update(
      (e) =>
          e..addAll(
            remoteFields
                .map((key, value) => MapEntry(key, value?.toString()))
                .nonNulls,
          ),
    );
    box.putAll(pCache.value);
  }

  final boxFields =
      box
          .toMap()
          .map((key, value) => MapEntry(key?.toString(), value))
          .nonNulls;

  pCache.update((e) => e..addAll(boxFields));

  print(3);

  const ref = ConfigFileRef(ref: 'config');
  final config = FileConfig(
    ref: ref,
    mapper: (key) {
      var value = pCache.value[key];
      if (value == null) {
        value = key;
        print(value);
        translate(
          value,
          locale,
          'AIzaSyDBpthU4aw_E4LtzIYeCizVwGk-QnJGTrA',
        ).then((translated) async {
          if (translated == null) return;
          print(translated);
          await firestore.patch('translations/$locale', {key: translated});
          await box.put(key, translated);
          pCache.update((e) => e..[key] = translated);
        });
      }
      return value;
    },
  );
  TranslationManager.$trFileConfig = config;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PodBuilder(
      pod: pCache,
      builder: (context, snapshot) {
        return MaterialApp(
          key: UniqueKey(),
          home: Scaffold(body: Column(children: [Text('How are you?'.tr())])),
        );
      },
    );
  }
}

Future<String?> translate(
  String text,
  String targetLocale,
  String apiKey,
) async {
  final targetLang = targetLocale.split('-')[0];
  final url = Uri.parse(
    'https://translation.googleapis.com/language/translate/v2?key=$apiKey',
  );
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'q': text, 'target': targetLang, 'format': 'text'}),
  );
  return jsonDecode(
        utf8.decode(response.bodyBytes),
      )?['data']?['translations']?[0]?['translatedText']
      as String?;
}

Future<String> login(String email, String password, String apiKey) async {
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

class Firestore {
  final String projectId;
  final String accessToken;
  final http.Client _httpClient = http.Client();

  Firestore({required this.projectId, required this.accessToken});

  String _getBaseURL() =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  @pragma('vm:prefer-inline')
  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>?> read(String path) async {
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
  }

  Future<void> write(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse(
      '${_getBaseURL()}/$collection?documentId=$documentId',
    );
    await _httpClient.post(
      url,
      headers: _authHeaders,
      body: jsonEncode({'fields': convertToFirestoreJson(data)}),
    );
  }

  Future<void> patch(String path, Map<String, dynamic> data) async {
    final updateMask = data.keys
        .map((key) => 'updateMask.fieldPaths=$key')
        .join('&');
    final url = Uri.parse('${_getBaseURL()}/$path?$updateMask');
    await _httpClient.patch(
      url,
      headers: _authHeaders,
      body: jsonEncode({'fields': convertToFirestoreJson(data)}),
    );
  }
}

Map<String, dynamic> convertToLocalJson(Map<String, dynamic> firestoreJson) {
  final result = <String, dynamic>{};
  firestoreJson.forEach((key, value) {
    result[key] = convertToLocalValue(value);
  });
  return result;
}

dynamic convertToLocalValue(dynamic value) {
  if (value is Map) {
    if (value.containsKey('mapValue')) {
      return convertToLocalJson(
        value['mapValue']['fields'] as Map<String, dynamic>,
      );
    } else if (value.containsKey('arrayValue')) {
      return (value['arrayValue']['values'])
          .map((dynamic e) => convertToLocalValue(e))
          .toList();
    } else if (value.containsKey('stringValue')) {
      return value['stringValue'];
    } else if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'] as String);
    } else if (value.containsKey('doubleValue')) {
      return double.parse(value['doubleValue'] as String);
    } else if (value.containsKey('booleanValue')) {
      return value['booleanValue'] == true;
    } else if (value.containsKey('timestampValue')) {
      return DateTime.parse(value['timestampValue'] as String);
    } else if (value.containsKey('nullValue')) {
      return null;
    }
  }
  throw UnsupportedError('Unsupported value: $value');
}

Map<String, dynamic> convertToFirestoreJson(Map<String, dynamic> localJson) {
  final result = <String, dynamic>{};
  localJson.forEach((key, value) {
    result[key] = convertToFirestoreValue(value);
  });
  return result;
}

Map<String, dynamic> convertToFirestoreValue(dynamic value) {
  if (value == null) {
    return {'nullValue': null};
  } else if (value is String) {
    return {'stringValue': value};
  } else if (value is int) {
    return {'integerValue': value.toString()};
  } else if (value is double) {
    return {'doubleValue': value.toString()};
  } else if (value is bool) {
    return {'booleanValue': value};
  } else if (value is DateTime) {
    return {'timestampValue': value.toIso8601String()};
  } else if (value is List<dynamic>) {
    return {
      'arrayValue': {'values': value.map(convertToFirestoreValue).toList()},
    };
  } else if (value is Map<String, dynamic>) {
    return {
      'mapValue': {'fields': convertToFirestoreJson(value)},
    };
  }
  throw UnsupportedError('Unsupported value type: ${value.runtimeType}');
}
