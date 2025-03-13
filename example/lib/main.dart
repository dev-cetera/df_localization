import 'package:df_config/_common.dart';
import 'package:df_localization/src/_etc/_etc.g.dart';

import 'package:df_pod/df_pod.dart';
import 'package:df_safer_dart/df_safer_dart.dart';
import 'package:flutter/material.dart';

import 'api_keys.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

Locale getCurrentLocale() {
  final locales = WidgetsBinding.instance.platformDispatcher.locales;
  return locales.first;
}

class Manager {
  Manager();

  final remoteStorage = FirestoreStorage(projectId: 'langchapp');
  final cachedStorage = PersistentStorage();

  static final pCache = Pod<Map<String, Map<String, String>>>({});

  Locale? _currentLocale;

  final _initialInitCompleter = Completer<void>();

  Future<void> loadRemoteTranslations(Locale locale) async {
    await _sequential.add((_) async {
      try {
        await _loadRemoteTranslations(locale);
      } catch (_) {}
      if (!_initialInitCompleter.isCompleted) {
        _initialInitCompleter.complete();
      }
      return const None();
    }).value;
  }

  Future<bool> loadCachedTranslations(Locale locale) async {
    try {
      _currentLocale = locale;
      final languageTag = locale.toLanguageTag().toLowerCase();
      final input = await cachedStorage.read('translations/$languageTag');
      if (input == null) return false;
      final fields = _convertFields(input);
      print('CACHED FIELDS: $fields');
      pCache.update((e) => e..addAll(fields));
      return true;
    } catch (e) {
      print('ERROR: $e');
      return false;
    }
  }

  Future<void> _loadRemoteTranslations(Locale locale) async {
    try {
      _currentLocale = locale;
      final languageTag = locale.toLanguageTag().toLowerCase();
      final input = await remoteStorage.readOrNull('translations/$languageTag');
      print('TEST? $input');
      if (input == null) return;
      final fields = _convertFields(input);
      print('REMOTE FIELDS: $fields');
      pCache.update((e) => e..addAll(fields));
      /*await*/
      cachedStorage.write(
        collectionPath: 'translations',
        documentId: languageTag,
        data: pCache.value,
      );
    } catch (e) {
      print('ERROR: $e');
    }
  }

  static Map<String, Map<String, String>> _convertFields(
    Map<String, dynamic>? input,
  ) {
    return input?.mapValues((e) => (e as Map).cast()) ?? {};
  }

  final _sequential = SafeSequential();

  Future<void> translateAndUpdate(String defaultValue, String key) async {
    await _sequential.add((_) async {
      await _initialInitCompleter.future;
      final test = Manager.pCache.value[key]?['to']?.toString();
      //if (test == null) {
      await _translateAndUpdate(defaultValue, key);
      //}
      return const None();
    }).value;
  }

  final _didRequestTranslate = <String>{};

  Future<void> _translateAndUpdate(String defaultValue, String key) async {
    if (_didRequestTranslate.contains(key)) return;
    _didRequestTranslate.add(key);
    final locale = _currentLocale!;
    final languageTag = locale.toLanguageTag().toLowerCase();

    print("TRANSLATING!!!");
    final translated = await GoogleTranslator.instance.translate(
      text: defaultValue,
      languageCode: locale.languageCode,
      countryCode: locale.countryCode,
      apiKey: GOOGLE_TRANSLATE_API_KEY,
    );
    // final translated = await OpenAITranslator.instance.translate(
    //   text: defaultValue,
    //   languageCode: locale.languageCode,
    //   countryCode: locale.countryCode,
    //   apiKey: OPENAI_TRANSLATE_API_KEY,
    // );
    if (translated == null) return;
    //print('TRANSLATED: $translated');
    pCache.update((e) => e..[key] = {'from': defaultValue, 'to': translated});
    //print('TO LOCAL: $languageTag');
    final f1 = cachedStorage.patch(
      documentPath: 'translations/$languageTag',
      data: {
        key: {'from': defaultValue, 'to': translated},
      },
    );
    //print('TO REMOTE: $languageTag');

    final f2 = remoteStorage.patch(
      documentPath: 'translations/$languageTag',
      data: {
        key: {'from': defaultValue, 'to': translated},
      },
    );

    await Future.wait([f1, f2]);
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //final locale = const Locale('es', 'mx');
  final locale = getCurrentLocale();
  final manager = Manager();

  final didLoad = await manager.loadCachedTranslations(locale);
  final f = manager.loadRemoteTranslations(locale);
  if (!didLoad) {
    await f;
  }

  final config = FileConfig(
    mapper: (textResult) {
      final textKey = textResult.key;
      var defaultValue = Manager.pCache.value[textKey]?['to']?.toString();
      if (defaultValue == null) {
        defaultValue = textResult.defaultValue;
        manager.translateAndUpdate(defaultValue, textKey);
      }
      return defaultValue;
    },
  );
  TranslationManager.config = config;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PodBuilder(
      pod: Manager.pCache,
      builder: (context, snapshot) {
        return MaterialApp(
          key: UniqueKey(),
          home: Scaffold(
            body: Column(
              children: [
                Text(
                  'How are you {displayName}?||how_are_you'.tr(
                    args: {'displayName': 'Robert'},
                  ),
                ),
                Text(
                  'Welcome to this app {displayName}||welcome_message'.tr(
                    args: {'displayName': 'Robert'},
                  ),
                ),
                Text(
                  'Hey there my man, do you want {object}||hey_there'.tr(
                    args: {'object': 'a brewski'},
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
