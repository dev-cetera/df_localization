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
import 'package:google_generative_ai/google_generative_ai.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main(List<String> arguments) async {
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
      defaultsTo: Directory.current.path,
    )
    ..addOption(
      'gemeni_api_key',
      help:
          'Obtain your API key here https://ai.google.dev/gemini-api/docs/api-key.',
    )
    ..addOption(
      'gemeni_model',
      help: 'The Gemeni LLM to use.',
      defaultsTo: 'gemini-1.5-flash-latest',
    )
    ..addOption(
      'locale',
      abbr: 'l',
      help: 'Specify your locale or language, e.g. "en-us" or "English"',
      defaultsTo: 'en-us',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory path for the generated translation JSON.',
      defaultsTo: Directory.current.path,
    )
    ..addOption(
      'output_type',
      abbr: 't',
      help:
          'Specify your output file type, e.g. "yaml", "yml", "json", "jsonc".',
      defaultsTo: 'yaml',
    );

  final argResults = parser.parse(arguments);

  // Print help if requested.
  if (argResults['help'] == true) {
    printBlue(parser.usage);
    return;
  }

  final rootPath = argResults['root']!.toString().trim();
  final gemeniApiKey = argResults['gemeni_api_key']?.toString().trim();
  final gemeniModel = argResults['gemeni_model']!.toString().trim();
  final locale = argResults['locale']!.toString().trim();
  final outputType = argResults['output_type']!.toString().toLowerCase().trim();
  final outputDirPath = argResults['output']!.toString().trim();
  final outputFilePath =
      '${p.join(outputDirPath, locale)}.$outputType'.toLowerCase();

  // Check if the provided rootPath exists.
  if (!Directory(rootPath).existsSync()) {
    printRed('[Error] The root directory does not exist: $rootPath');
    exit(1);
  }

  // Define a function to insert pairs into the tanslation map.
  void insertPairIntoMap(
      Map<String, dynamic> translationMap, MapEntry<String, String> pair,) {
    final keyParts = pair.key.split('.');
    for (var i = 0; i < keyParts.length; i++) {
      final part = keyParts[i];
      if (i == keyParts.length - 1) {
        translationMap[part] = pair.value;
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
  Map<String, String> collectPairs(String rootPath) {
    final pairs = <String, String>{};
    final dir = Directory(rootPath);
    final systemEntities = dir.listSync(recursive: true, followLinks: false);
    for (final systemEntity in systemEntities) {
      if (systemEntity is File &&
          systemEntity.path.toLowerCase().endsWith('.dart')) {
        final content = systemEntity.readAsStringSync();
        // See: regexr.com/86id8
        final regex =
            RegExp(r'''["'](?:([^|"']+)\|\|)?([^"']+)["']\s*\.\s*tr\(''');
        for (final match in regex.allMatches(content)) {
          final key = (match.group(2) ?? 'key_${pairs.length}').toLowerCase();
          final value =
              match.group(1) ?? match.group(2) ?? 'value_${pairs.length}';
          pairs[key] = '"$value"';
        }
      }
    }
    return pairs;
  }

  // Collect all keys and add them to the translationMap.
  final translationMap = <String, dynamic>{};
  final pairs = collectPairs(rootPath).entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final pair in pairs) {
    insertPairIntoMap(translationMap, pair);
  }

  // Get the output file extension:
  final isJson = outputType == 'json' || outputType == 'jsonc';
  final isYaml = outputType == 'yaml' || outputType == 'yml';

  // Create the translation output file.
  final translationFile = File(outputFilePath);
  final translationSink = translationFile.openWrite();

  // / Create the directory if it doesn't exist.
  final directory = Directory(outputDirPath).parent;
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  // Write output as JSON or YAML.
  if (isJson) {
    final data = const JsonEncoder.withIndent('  ').convert(translationMap);
    final transaltedData = gemeniApiKey != null
        ? await translateWithGemeni(
            data: data,
            gemeniApiKey: gemeniApiKey,
            gemeniModel: gemeniModel,
            locale: locale,
          )
        : data;
    translationSink.write(transaltedData);
    translationSink.close();
  } else if (isYaml) {
    final data = mapToYaml(translationMap);
    final transaltedData = gemeniApiKey != null
        ? await translateWithGemeni(
            data: data,
            gemeniApiKey: gemeniApiKey,
            gemeniModel: gemeniModel,
            locale: locale,
          )
        : data;
    translationSink.write(transaltedData);
    translationSink.close();
  }

  printGreen(
    '[Success] Translation file generated at: $outputFilePath',
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

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Translate [data] to [locale] using Gemeni.
Future<String?> translateWithGemeni({
  required String data,
  required String gemeniApiKey,
  required String gemeniModel,
  required String locale,
}) async {
  final model = GenerativeModel(
    model: gemeniModel,
    apiKey: gemeniApiKey,
  );

  final content = [
    Content.text('Transalte the following translation file into $locale:'),
    Content.text(data),
  ];
  final response = await model.generateContent(content);
  return response.text;
}
