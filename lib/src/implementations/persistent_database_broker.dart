//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Copyright © dev-cetera.com & contributors.
//
// The use of this source code is governed by an MIT-style license described in
// the LICENSE file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import 'package:shared_preferences/shared_preferences.dart';

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class PersistentDatabaseBroker extends DatabaseInterface {
  //
  //
  //

  const PersistentDatabaseBroker();

  //
  //
  //

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  //
  //
  //

  @override
  Async<Map<String, dynamic>> read(String path) {
    return Async(() async {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(path);
      if (jsonString == null) {
        throw Err('No data found at path: $path');
      }
      return jsonDecode(jsonString) as Map<String, dynamic>;
    });
  }

  //
  //
  //

  @override
  Async<Unit> write({
    required String path,
    required Map<String, dynamic> data,
  }) {
    return Async(() async {
      final prefs = await _getPrefs();
      final result = await prefs.setString(path, jsonEncode(data));
      if (!result) {
        throw Err('Failed to write data at path: $path');
      }
      return Unit();
    });
  }

  //
  //
  //

  @override
  Async<Unit> patch({
    required String path,
    required Map<String, dynamic> data,
  }) {
    return Async(() async {
      final prefs = await _getPrefs();
      final existingJson = prefs.getString(path);

      final Map<String, dynamic> mergedData;
      if (existingJson != null) {
        final existingData = jsonDecode(existingJson) as Map<String, dynamic>;
        mergedData = {...existingData, ...data};
      } else {
        mergedData = data;
      }

      final result = await prefs.setString(path, jsonEncode(mergedData));
      if (!result) {
        throw Err('Failed to patch data at path: $path');
      }
      return Unit();
    });
  }
}
