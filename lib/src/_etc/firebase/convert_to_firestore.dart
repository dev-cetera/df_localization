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
