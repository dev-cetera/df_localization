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

Map<String, dynamic> convertToLocalJson(Map<String, dynamic> firestoreJson) {
  final result = <String, dynamic>{};
  firestoreJson.forEach((key, value) {
    result[key] = convertToLocalValue(value);
  });
  return result;
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

dynamic convertToLocalValue(dynamic value) {
  if (value is Map) {
    if (value.containsKey('mapValue')) {
      final out = value['mapValue']['fields'] as Map<String, dynamic>?;
      if (out == null) {
        return null;
      }
      return convertToLocalJson(out);
    } else if (value.containsKey('arrayValue')) {
      final out = (value['arrayValue']['values']) as Iterable<dynamic>?;
      return out?.map((dynamic e) => convertToLocalValue(e)).toList();
    } else if (value.containsKey('stringValue')) {
      return value['stringValue'];
    } else if (value.containsKey('integerValue')) {
      final out = value['integerValue'] as String?;
      if (out == null) {
        return null;
      }
      return int.tryParse(out);
    } else if (value.containsKey('doubleValue')) {
      final out = value['doubleValue'] as String?;
      if (out == null) {
        return null;
      }
      return double.tryParse(out);
    } else if (value.containsKey('booleanValue')) {
      return value['booleanValue'] == true;
    } else if (value.containsKey('timestampValue')) {
      final out = value['timestampValue'] as String?;
      if (out == null) {
        return null;
      }
      return DateTime.tryParse(out);
    } else if (value.containsKey('nullValue')) {
      return null;
    }
  }
  throw UnsupportedError('Unsupported value: $value');
}
