import 'package:material_ui/material_ui.dart';

import 'pages/practice_page.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(SpeakMindApp(settings: settings));
}

class SpeakMindApp extends StatelessWidget {
  const SpeakMindApp({super.key, required this.settings});

  final SettingsStore settings;

  static const _seed = Color(0xFF3949AB);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpeakMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      ),
      home: PracticePage(settings: settings),
    );
  }
}
