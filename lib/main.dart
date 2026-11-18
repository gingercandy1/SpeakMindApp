import 'package:material_ui/material_ui.dart';
import 'package:speakmind/settings.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/theme.dart';
import 'package:speakmind/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.load();
  final progress = await ProgressStore.load();
  runApp(MyApp(settings: store, progress: progress));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.settings, required this.progress});

  final SettingsStore settings;
  final ProgressStore progress;

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
        home: HomePage(settings: settings, progress: progress),
      ),
    );
  }
}
