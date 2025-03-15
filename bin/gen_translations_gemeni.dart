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

import 'dart:convert';
import 'dart:io';
import 'package:df_log/df_log.dart';
import 'package:path/path.dart' as p;
import 'package:args/args.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main(List<String> arguments) async {
  DebugLog.debugOnly = false;
  printBlue('Starting generator. Please wait...');
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
      'api_key',
      help: 'Obtain your API key here https://ai.google.dev/gemini-api/docs/api-key.',
    )
    ..addOption(
      'model',
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
      'type',
      abbr: 't',
      help: 'Specify your output file type, e.g. "yaml", "yml", "json", "jsonc".',
      defaultsTo: 'yaml',
    );

  final argResults = parser.parse(arguments);

  // Print help if requested.
  if (argResults['help'] == true) {
    printBlue(parser.usage);
    return;
  }

  final rootPath = argResults['root']!.toString().trim();
  final apiKey = argResults['api_key']?.toString().trim();
  final model = argResults['model']!.toString().trim();
  final locale = argResults['locale']!.toString().trim();
  final type = argResults['type']!.toString().toLowerCase().trim();
  final outputDirPath = argResults['output']!.toString().trim();
  final outputFilePath = '${p.join(outputDirPath, locale)}.$type'.toLowerCase();

  // Check if the provided rootPath exists.
  if (!Directory(rootPath).existsSync()) {
    printRed('Error! The root directory does not exist: $rootPath');
    exit(1);
  }

  // Define a function to insert pairs into the tanslation map.
  void insertPairIntoMap(
    Map<String, dynamic> translationMap,
    MapEntry<String, String> pair,
  ) {
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
            'Error! The key “$part” is being used both as a string value and as a map (e.g., “$part”: “value” and “$part”: {“key”: “value”}). It must be one or the other. Please correct this in your code and try again.',
          );
          exit(1);
        }
      }
    }
  }

  bool isWord(String input) {
    // Define a regular expression to match valid words
    final regex = RegExp(r'^[a-zA-Z0-9_-]+$');

    // Check if the input matches the regular expression
    return regex.hasMatch(input);
  }

  // Recursively traverse the rootPath to find all keys in Dart files.
  Map<String, String> collectPairs(String rootPath) {
    final pairs = <String, String>{};
    final dir = Directory(rootPath);
    final systemEntities = dir.listSync(recursive: true, followLinks: false);
    for (final systemEntity in systemEntities) {
      if (systemEntity is File && systemEntity.path.toLowerCase().endsWith('.dart')) {
        final content = systemEntity.readAsStringSync();
        // See: regexr.com/86id8
        final regex = RegExp(
          r'''["'](?:([^|"']+)\|\|)?([^"']+)["']\s*\.\s*tr\(''',
        );
        for (final match in regex.allMatches(content)) {
          final key = (match.group(2) ?? 'key_${pairs.length}');
          final value = match.group(1) ?? match.group(2) ?? 'value_${pairs.length}';
          final keyOrExisting = pairs.keys.firstWhere(
            (k) => k.toLowerCase() == key.toLowerCase(),
            orElse: () => key,
          );
          if (isWord(keyOrExisting)) {
            pairs[keyOrExisting] = value;
          } else {
            printYellow(
              'Warning! The key “$key” is not a valid word. It will be ignored.',
            );
          }
        }
      }
    }
    return pairs;
  }

  // Collect all keys and add them to the translationMap.
  final translationMap = <String, dynamic>{};
  final pairs = collectPairs(rootPath).entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final pair in pairs) {
    insertPairIntoMap(translationMap, pair);
  }

  // Get the output file extension:
  final isJson = type == 'json' || type == 'jsonc';
  final isYaml = type == 'yaml' || type == 'yml';

  // Create the translation output file.
  final translationFile = File(outputFilePath);
  final translationSink = translationFile.openWrite();

  // Create the directory if it doesn't exist.
  final directory = Directory(outputDirPath).parent;
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  // Translate using Gemeni if an API key is provided and verify that the
  // translation is valid JSON.
  Map<String, dynamic> checked;
  try {
    final input = const JsonEncoder.withIndent('  ').convert(translationMap);
    final transalted = apiKey != null
        ? await translateWithGemeni(
            data: input,
            apiKey: apiKey,
            gemeniModel: model,
            locale: locale,
          )
        : input;

    checked = (jsonDecode(transalted) as Map).cast<String, dynamic>();
  } catch (e) {
    printBlue(e);
    printRed(
      'Error! The translation could not be generated. Please check your Gemeni API key and try again.',
    );
    exit(1);
  }

  // Write output as JSON or YAML.
  if (isJson) {
    final output = const JsonEncoder.withIndent('  ').convert(checked);
    translationSink.write(output);
    translationSink.close();
  } else if (isYaml) {
    final output = mapToYaml(checked);
    translationSink.write(output);
    translationSink.close();
  }

  // ---------------------------------------------------------------------------

  // Notify end.
  printGreen('Success! Translation file generated at: $outputFilePath');
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
      buffer.writeln('$spaces$key: "$value"');
    }
  });

  return buffer.toString();
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Translate [data] to [locale] using Gemeni.
Future<String> translateWithGemeni({
  required String data,
  required String apiKey,
  required String gemeniModel,
  required String locale,
}) async {
  final model = GenerativeModel(model: gemeniModel, apiKey: apiKey);
  final content = [
    Content.text('Translate the following JSON translation file into $locale:'),
    Content.text(data),
  ];
  final response = await model.generateContent(content);
  var text = response.text!.trim();

  // Remove any markdown code block wrapping.
  if (text.startsWith('```')) {
    // Remove the opening code block.
    final startIndex = text.indexOf('\n') + 1; // Start after the first newline
    text = text.substring(startIndex);

    // Remove the closing code block if it exists.
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3).trim();
    }
  }

  return text.trim();
}
