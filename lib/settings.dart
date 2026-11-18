import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A language the app can practise.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.label,
    required this.name,
    required this.ttsLocale,
    required this.builtIn,
    required this.customKey,
  });

  /// Code the server expects.
  final String code;

  /// Short label for the switch.
  final String label;

  /// Name shown to the user, in Chinese.
  final String name;

  /// Locale for the phone's own speech engine, used when the server cannot speak.
  final String ttsLocale;
  final List<String> builtIn;
  final String customKey;
}

/// English sentences shipped with the app. The user can add their own.
const builtInSentences = <String>[
  'The quick brown fox jumps over the lazy dog.',
  'I think this is a very good idea.',
  'She sells seashells by the seashore.',
  'Could you tell me how to get to the station?',
  'The weather is really nice this morning.',
  'I would like a cup of coffee, please.',
  'Three thin thieves thought a thousand thoughts.',
  'We usually have dinner together on Friday.',
  'Thank you for helping me with this problem.',
  'It was the best decision I have ever made.',
];

/// Spanish sentences shipped with the app.
const builtInSentencesEs = <String>[
  'Me gustaría un café con leche, por favor.',
  '¿Podría decirme cómo llegar a la estación?',
  'Hoy hace muy buen tiempo en la ciudad.',
  'Creo que esta es una muy buena idea.',
  'Tres tristes tigres tragaban trigo en un trigal.',
  'Mi hermano trabaja en un banco cerca de aquí.',
  'Normalmente cenamos juntos los viernes por la noche.',
  'Muchas gracias por ayudarme con este problema.',
  '¿Dónde está el baño, por favor?',
  'Fue la mejor decisión que he tomado en mi vida.',
];

const languages = <AppLanguage>[
  AppLanguage(
    code: 'en',
    label: 'EN',
    name: '英语',
    ttsLocale: 'en-US',
    builtIn: builtInSentences,
    // The key English sentences were always stored under.
    customKey: 'custom_sentences',
  ),
  AppLanguage(
    code: 'es',
    label: 'ES',
    name: '西班牙语',
    ttsLocale: 'es-ES',
    builtIn: builtInSentencesEs,
    customKey: 'custom_sentences_es',
  ),
];

/// Settings kept on the device.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  /// 10.0.2.2 is how the Android emulator reaches the computer it runs on.
  /// A real phone needs the computer's LAN address instead.
  static const defaultServerUrl = 'http://10.0.2.2:8000';

  static const _serverUrlKey = 'server_url';
  static const _languageKey = 'language';
  static const _themeKey = 'theme_mode';

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async =>
      SettingsStore(await SharedPreferences.getInstance());

  /// App appearance (F4 dark mode): system default, light, or dark.
  ThemeMode get themeMode {
    return switch (_prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await _prefs.setString(
      _themeKey,
      switch (value) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
    );
    notifyListeners();
  }

  String get serverUrl => _prefs.getString(_serverUrlKey) ?? defaultServerUrl;

  Future<void> setServerUrl(String value) async {
    await _prefs.setString(_serverUrlKey, value.trim());
    notifyListeners();
  }

  /// The language being practised.
  AppLanguage get language {
    final code = _prefs.getString(_languageKey);
    return languages.firstWhere((l) => l.code == code, orElse: () => languages.first);
  }

  Future<void> setLanguage(AppLanguage value) async {
    await _prefs.setString(_languageKey, value.code);
    notifyListeners();
  }

  /// The user's own sentences in the current language.
  List<String> get customSentences =>
      _prefs.getStringList(language.customKey) ?? const [];

  /// The user's own sentences first, then the built-in ones, in the current language.
  List<String> get sentences => [...customSentences, ...language.builtIn];

  Future<void> addSentence(String sentence) async {
    final text = sentence.trim();
    if (text.isEmpty || sentences.contains(text)) return;
    await _prefs.setStringList(language.customKey, [text, ...customSentences]);
    notifyListeners();
  }

  Future<void> removeSentence(String sentence) async {
    await _prefs.setStringList(
      language.customKey,
      customSentences.where((s) => s != sentence).toList(),
    );
    notifyListeners();
  }
}
