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
import 'package:yaml_writer/yaml_writer.dart';

void main(List<String> arguments) {
  // 1. Get the arguments.
  final parser = ArgParser()
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
        'translations.json',
      ),
    );

  final argResults = parser.parse(arguments);
  final rootPath = argResults['root']?.toString() ?? '.';
  final outputPath = argResults['output']?.toString() ?? '.';

  // 2. Check if the provided rootPath exists.
  if (!Directory(rootPath).existsSync()) {
    printRed('[Error] The root directory does not exist: $rootPath');
    exit(1);
  }

  // 3. Define a function to insert keys into the tanslation map.
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

  // 4. Recursively traverse the rootPath to find all keys in Dart files.
  List<String> collectKeys(String rootPath) {
    final keys = <String>[];
    final dir = Directory(rootPath);
    final systemEntities = dir.listSync(recursive: true, followLinks: false);
    for (final systemEntity in systemEntities) {
      if (systemEntity is File && systemEntity.path.toLowerCase().endsWith('.dart')) {
        final content = systemEntity.readAsStringSync();
        // Find keys in the pattern '||key'.tr() or 'key'.tr(:
        final regex = RegExp(r"'(?:[^']+)\|\|([^']+)'\.tr\(|'([^']+)'\.tr\(");
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

  // 5. Collect all keys and add them to the translationMap.
  final translationMap = <String, dynamic>{};
  final keys = collectKeys(rootPath)..sort();
  for (final key in keys) {
    insertKeyIntoMap(translationMap, key);
  }

  // 6. Get the output file extension:
  final extension = p.extension(outputPath).toLowerCase();
  final isJson = extension == '.json' || extension == '.jsonc';
  final isYaml = extension == '.yaml' || extension == '.yml';

  // 7. Create the translation output file.
  final translationFile = File(outputPath);
  final translationSink = translationFile.openWrite();

  // 8. Write output as JSON or YAML.
  if (isJson) {
    translationSink.write(
      const JsonEncoder.withIndent('  ').convert(translationMap),
    );
    translationSink.close();
  } else if (isYaml) {
    final yamlWriter = YamlWriter();
    translationSink.write(yamlWriter.write(translationMap));
    translationSink.close();
  }

  printGreen(
    '[Success] Translation file generated at: $outputPath',
  );
}
