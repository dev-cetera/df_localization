import 'package:df_config/_common.dart';
import 'package:df_localization/src/_etc/_etc.g.dart';

import 'package:df_pod/df_pod.dart';
import 'package:df_safer_dart/df_safer_dart.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class Manager {
  Manager();

  Box<String>? _box;

  final firestore = Firestore(projectId: 'langchapp');

  static final pCache = Pod<Map<String, String>>({});

  Locale? _currentLocale;

  Future<Manager> init(Locale locale) async {
    await _sequential.last.value;
    pCache.set({});
    _box?.close();
    _box = null;
    _currentLocale = locale;
    final languageTag = locale.toLanguageTag();

    // Update pCache with local fields.
    _box = await Hive.openBox<String>(languageTag);
    final localFields = _convertLocalFields(_box!.toMap());
    pCache.update((e) => e..addAll(localFields));

    // Update pCache with remote fields.
    final remoteInput = await firestore.read('translations/$languageTag');
    final remoteFields = _convertRemoteFields(remoteInput);
    pCache.update((e) => e..addAll(remoteFields));

    // Update local fields with remote fields.
    _box!.putAll(pCache.value);

    // Return this for chaining.
    return this;
  }

  static Map<String, String> _convertLocalFields(Map<dynamic, String>? input) {
    return input?.mapKeys((e) => e.toString()) ?? {};
  }

  static Map<String, String> _convertRemoteFields(Map<String, dynamic>? input) {
    return input?.mapValues((e) => e?.toString()).nonNullValues ?? {};
  }

  final _sequential = SafeSequential();

  Future<void> translateAndUpdate(String defaultValue, String key) async {
    await _sequential.add((_) async {
      await _translateAndUpdate(defaultValue, key);
      return const None();
    }).value;
  }

  Future<void> _translateAndUpdate(String defaultValue, String key) async {
    final locale = _currentLocale!;
    final languageTag = locale.toLanguageTag();
    final translated = await GoogleTranslator.instance.translate(
      text: defaultValue,
      languageCode: locale.languageCode,
      countryCode: locale.countryCode!,
      apiKey: 'AIzaSyDBpthU4aw_E4LtzIYeCizVwGk-QnJGTrA',
    );
    // final translated = await OpenAITranslator.instance.translate(
    //   text: defaultValue,
    //   languageCode: locale.languageCode,
    //   countryCode: locale.countryCode!,
    //   apiKey:
    //       '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',
    // );
    //assert(translated != null);
    if (translated == null) return;
    pCache.update((e) => e..[key] = translated);
    assert(_box != null);
    if (_box == null) return;
    final f0 = _box!.put(key, translated);
    final f2 = firestore.patch(
      documentPath: 'translations/$languageTag',
      data: {key: translated},
    );
    await Future.wait([f0, f2]);
  }
}

void main() async {
  await setupTranslations();
  runApp(const MyApp());
}

Future<void> setupTranslations() async {
  final locale = const Locale('es', 'mx');
  final manager = await Manager().init(locale);
  final config = FileConfig(
    mapper: (textResult) {
      final textKey = textResult.key;
      var defaultValue = Manager.pCache.value[textKey];
      if (defaultValue == null) {
        defaultValue = textResult.defaultValue;
        manager.translateAndUpdate(defaultValue, textKey);
      }
      return defaultValue;
    },
  );
  TranslationManager.config = config;
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
                  'How are you {dude}?||eee'.tr(args: {'dude': 'DOOODE MAN'}),
                ),
                Text(
                  'Welcome to this app {displayName}||welcome-message'.tr(
                    args: {'displayName': 'Robert'},
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
