import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersistentStorage {
  //
  //
  //

  PersistentStorage();

  //
  //
  //

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  //
  //
  //

  Future<Map<String, dynamic>?> read(String path) async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(path);
    if (jsonString != null) {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }
    return null;
  }

  //
  //
  //

  Future<void> write({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await _getPrefs();
    final key = '$collectionPath/$documentId';
    await prefs.setString(key, jsonEncode(data));
  }

  //
  //
  //

  Future<void> patch({
    required String documentPath,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await _getPrefs();
    final existingJson = prefs.getString(documentPath);
    if (existingJson != null) {
      final existingData = jsonDecode(existingJson) as Map<String, dynamic>;
      final mergedData = {...existingData, ...data};
      await prefs.setString(documentPath, jsonEncode(mergedData));
    } else {
      await prefs.setString(documentPath, jsonEncode(data));
    }
  }
}
