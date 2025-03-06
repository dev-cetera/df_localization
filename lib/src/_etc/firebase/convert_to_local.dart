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
