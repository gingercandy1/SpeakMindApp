import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:speakmind/api.dart';
import 'package:speakmind/history.dart';
import 'package:speakmind/settings.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/theme.dart';
import 'package:speakmind/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.load();
  final progress = await ProgressStore.load();
  final history = await HistoryStore.load();
  // Best-effort backup of any records left unsynced last time. Never
  // awaited: a slow or unreachable server must not delay startup.
  unawaited(history.sync(ApiClient(store.serverUrl)));
  runApp(MyApp(settings: store, progress: progress, history: history));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settings,
    required this.progress,
    required this.history,
  });

  final SettingsStore settings;
  final ProgressStore progress;
  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    // Rebuilds the MaterialApp when the theme mode changes (F4 dark mode).
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'SpeakMind',
        theme: speakMindTheme(),
        darkTheme: speakMindDarkTheme(),
        themeMode: settings.themeMode,
        home: HomePage(settings: settings, progress: progress, history: history),
      ),
    );
  }
}
