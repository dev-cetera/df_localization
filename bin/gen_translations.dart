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

import 'dart:convert';
import 'dart:io';

import 'package:ai_broker/ai_broker.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

// Minimal ANSI-colored console output. Deliberately self-contained so the
// published package does not carry a logging dependency just for this CLI.
final class Log {
  static void printBlue(Object? m) => print('\x1B[94m$m\x1B[0m');
  static void printGreen(Object? m) => print('\x1B[92m$m\x1B[0m');
  static void printYellow(Object? m) => print('\x1B[93m$m\x1B[0m');
  static void printRed(Object? m) => print('\x1B[91m$m\x1B[0m');
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

const _kProviders = {
  'claude': _ProviderSpec(
    label: 'Anthropic (Claude)',
    defaultModel: 'claude-3-haiku-20240307',
  ),
  'gemini': _ProviderSpec(
    label: 'Google (Gemini)',
    defaultModel: 'gemini-1.5-flash-latest',
  ),
  'openai': _ProviderSpec(
    label: 'OpenAI',
    defaultModel: 'gpt-4o-mini',
  ),
};

void main(List<String> arguments) async {
  Log.printBlue('Starting generator. Please wait...');

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
      'provider',
      abbr: 'p',
      help: 'Which LLM to use.',
      allowed: _kProviders.keys,
      defaultsTo: 'gemini',
    )
    ..addOption(
      'api_key',
      help: 'Your provider API key. Required unless you only want to dump the '
          'untranslated key map.',
    )
    ..addOption(
      'model',
      help: 'Model id. Defaults to a sensible per-provider choice — see '
          '`--help` after picking a provider.',
    )
    ..addOption(
      'locale',
      abbr: 'l',
      help: 'Target locale, e.g. "de-de" or "es-mx".',
      defaultsTo: 'en-us',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated translation file.',
      defaultsTo: Directory.current.path,
    )
    ..addOption(
      'type',
      abbr: 't',
      help: 'Output file type: "yaml", "yml", "json", or "jsonc".',
      defaultsTo: 'yaml',
    );

  final argResults = parser.parse(arguments);

  if (argResults['help'] == true) {
    Log.printBlue(parser.usage);
    return;
  }

  final rootPath = argResults['root']!.toString().trim();
  final providerId = argResults['provider']!.toString().trim();
  final apiKey = argResults['api_key']?.toString().trim();
  final providerSpec = _kProviders[providerId]!;
  final model =
      argResults['model']?.toString().trim() ?? providerSpec.defaultModel;
  final locale = argResults['locale']!.toString().trim();
  final type = argResults['type']!.toString().toLowerCase().trim();
  final outputDirPath = argResults['output']!.toString().trim();
  final outputFilePath = '${p.join(outputDirPath, locale)}.$type'.toLowerCase();

  if (!Directory(rootPath).existsSync()) {
    Log.printRed('Error! The root directory does not exist: $rootPath');
    exit(1);
  }

  // Collect every (key, defaultText) pair from `.tr()` call sites.
  final pairs = _collectPairs(rootPath).entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final translationMap = <String, dynamic>{};
  for (final pair in pairs) {
    _insertPairIntoMap(translationMap, pair);
  }

  final isJson = type == 'json' || type == 'jsonc';
  final isYaml = type == 'yaml' || type == 'yml';
  if (!isJson && !isYaml) {
    Log.printRed('Error! Unsupported output type: $type');
    exit(1);
  }

  // Ensure the output directory exists.
  Directory(outputDirPath).createSync(recursive: true);

  // Translate via the chosen LLM if an API key is provided, else write the
  // map untranslated so the user can hand-edit it.
  Map<String, dynamic> checked;
  try {
    final input = const JsonEncoder.withIndent('  ').convert(translationMap);
    final translated = apiKey != null
        ? await _translateWithLlm(
            data: input,
            apiKey: apiKey,
            providerId: providerId,
            model: model,
            locale: locale,
          )
        : input;
    checked = (jsonDecode(translated) as Map).cast<String, dynamic>();
  } catch (e) {
    Log.printBlue(e);
    Log.printRed(
      'Error! The translation could not be generated. Check your '
      '${providerSpec.label} API key and try again.',
    );
    exit(1);
  }

  final translationFile = File(outputFilePath);
  final translationSink = translationFile.openWrite();
  if (isJson) {
    translationSink.write(const JsonEncoder.withIndent('  ').convert(checked));
  } else {
    translationSink.write(_mapToYaml(checked));
  }
  await translationSink.close();

  Log.printGreen('Success! Translation file generated at: $outputFilePath');
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void _insertPairIntoMap(
  Map<String, dynamic> translationMap,
  MapEntry<String, String> pair,
) {
  final keyParts = pair.key.split('.');
  var cursor = translationMap;
  for (var i = 0; i < keyParts.length; i++) {
    final part = keyParts[i];
    if (i == keyParts.length - 1) {
      cursor[part] = pair.value;
    } else {
      cursor[part] = cursor[part] ?? <String, dynamic>{};
      try {
        cursor = cursor[part] as Map<String, dynamic>;
      } catch (_) {
        Log.printRed(
          'Error! The key "$part" is being used both as a string value and '
          'as a map. It must be one or the other. Please correct this in '
          'your code and try again.',
        );
        exit(1);
      }
    }
  }
}

bool _isWord(String input) => RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input);

Map<String, String> _collectPairs(String rootPath) {
  final pairs = <String, String>{};
  final entities = Directory(rootPath).listSync(
    recursive: true,
    followLinks: false,
  );
  // See: regexr.com/86id8
  final regex = RegExp(r'''["'](?:([^|"']+)\|\|)?([^"']+)["']\s*\.\s*tr\(''');
  for (final entity in entities) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    for (final match in regex.allMatches(content)) {
      final key = match.group(2) ?? 'key_${pairs.length}';
      final value = match.group(1) ?? match.group(2) ?? 'value_${pairs.length}';
      final keyOrExisting = pairs.keys.firstWhere(
        (k) => k.toLowerCase() == key.toLowerCase(),
        orElse: () => key,
      );
      if (_isWord(keyOrExisting)) {
        pairs[keyOrExisting] = value;
      } else {
        Log.printYellow(
          'Warning! The key "$key" is not a valid word. It will be ignored.',
        );
      }
    }
  }
  return pairs;
}

String _mapToYaml(Map<String, dynamic> map, {int indent = 0}) {
  final buffer = StringBuffer();
  final spaces = ' ' * indent;
  map.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      buffer.writeln('$spaces$key:');
      buffer.write(_mapToYaml(value, indent: indent + 2));
    } else {
      buffer.writeln('$spaces$key: "$value"');
    }
  });
  return buffer.toString();
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

Future<String> _translateWithLlm({
  required String data,
  required String apiKey,
  required String providerId,
  required String model,
  required String locale,
}) async {
  final broker = switch (providerId) {
    'claude' => AnthropicBroker(),
    'gemini' => GeminiBroker(),
    'openai' => OpenAiBroker(),
    _ => throw ArgumentError('Unknown provider: $providerId'),
  };
  var text = await broker.chat(
    apiKey: apiKey,
    model: model,
    request: ChatRequest(
      system: 'You are an app localization translator. Translate the values in '
          'the provided JSON object into the target locale. Preserve keys '
          'and JSON structure exactly. Do not translate placeholders like '
          '{...} or {{...}}. Respond with the JSON object only — no prose, '
          'no markdown fences.',
      messages: [
        AiMessage.user(
          'Target locale: $locale\n\nJSON to translate:\n$data',
        ),
      ],
      temperature: 0.2,
      maxTokens: 4000,
    ),
  );
  text = text.trim();
  // Strip a wrapping markdown fence if the model added one anyway.
  if (text.startsWith('```')) {
    final firstNewline = text.indexOf('\n');
    if (firstNewline != -1) text = text.substring(firstNewline + 1);
    if (text.endsWith('```')) text = text.substring(0, text.length - 3);
    text = text.trim();
  }
  return text;
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

class _ProviderSpec {
  final String label;
  final String defaultModel;
  const _ProviderSpec({required this.label, required this.defaultModel});
}
