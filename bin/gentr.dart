//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Dart/Flutter (DF) Packages by DevCetra.com & contributors. The use of this
// source code is governed by an MIT-style license described in the LICENSE
// file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import 'dart:convert';
import 'dart:io';
import 'package:df_log/df_log.dart';
import 'package:path/path.dart' as p;
import 'package:args/args.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main(List<String> arguments) {
  // Get the arguments.
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message.',
    )
    ..addOption(
      'root',
      abbr: 'r',
      help: 'Root directory to search for translation keys.',
      mandatory: true,
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output path for the generated translation JSON.',
      defaultsTo: p.join(
        Directory.current.path,
        'translations.yaml',
      ),
    );

  final argResults = parser.parse(arguments);

  // Print help if requested.
  if (argResults['help'] != null) {
    printBlue(parser.usage);
    return;
  }

  final rootPath = argResults['root']?.toString() ?? '.';
  final outputPath = argResults['output']?.toString() ?? '.';

  // Check if the provided rootPath exists.
  if (!Directory(rootPath).existsSync()) {
    printRed('[Error] The root directory does not exist: $rootPath');
    exit(1);
  }

  // Define a function to insert keys into the tanslation map.
  void insertKeyIntoMap(Map<String, dynamic> translationMap, String key) {
    final parts = key.split('.');

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i == parts.length - 1) {
        translationMap[part] = 'TODO';
      } else {
        translationMap[part] = translationMap[part] ?? <String, dynamic>{};
        try {
          translationMap = translationMap[part] as Map<String, dynamic>;
        } catch (e) {
          printRed(
            '[Error] The key “$part” is being used both as a string value and as a map (e.g., “$part”: “value” and “$part”: {“key”: “value”}). It must be one or the other. Please correct this in your code and try again.',
          );
          exit(1);
        }
      }
    }
  }

  // Recursively traverse the rootPath to find all keys in Dart files.
  List<String> collectKeys(String rootPath) {
    final keys = <String>[];
    final dir = Directory(rootPath);
    final systemEntities = dir.listSync(recursive: true, followLinks: false);
    for (final systemEntity in systemEntities) {
      if (systemEntity is File && systemEntity.path.toLowerCase().endsWith('.dart')) {
        final content = systemEntity.readAsStringSync();
        // Find keys in the pattern '||key'.tr() or 'key'.tr(:
        final regex = RegExp(r"'(?:[^']+)\|\|([^']+)'\s*\.tr\(|'([^']+)'\s*\.tr\(");
        for (final match in regex.allMatches(content)) {
          final key = match.group(1) ?? match.group(2);
          if (key != null && key.isNotEmpty) {
            keys.add(key);
          }
        }
      }
    }
    return keys;
  }

  // Collect all keys and add them to the translationMap.
  final translationMap = <String, dynamic>{};
  final keys = collectKeys(rootPath)..sort();
  for (final key in keys) {
    insertKeyIntoMap(translationMap, key);
  }

  // Get the output file extension:
  final extension = p.extension(outputPath).toLowerCase();
  final isJson = extension == '.json' || extension == '.jsonc';
  final isYaml = extension == '.yaml' || extension == '.yml';

  // Create the translation output file.
  final translationFile = File(outputPath);
  final translationSink = translationFile.openWrite();

  // Write output as JSON or YAML.
  if (isJson) {
    translationSink.write(
      const JsonEncoder.withIndent('  ').convert(translationMap),
    );
    translationSink.close();
  } else if (isYaml) {
    translationSink.write(mapToYaml(translationMap));
    translationSink.close();
  }

  printGreen(
    '[Success] Translation file generated at: $outputPath',
  );
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

// Convert a map to a YAML string.
String mapToYaml(Map<String, dynamic> map, {int indent = 0}) {
  final buffer = StringBuffer();
  final spaces = ' ' * indent;

  map.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      buffer.writeln('$spaces$key:');
      buffer.write(mapToYaml(value, indent: indent + 2));
    } else {
      buffer.writeln('$spaces$key: $value');
    }
  });

  return buffer.toString();
}
