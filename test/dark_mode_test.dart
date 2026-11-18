/// F4 tests: dark mode theme builds, persists, and the home shell renders
/// under it.
///
/// The asset load in a testWidgets body runs in FakeAsync and never
/// completes (see widget_test), so the graph is preloaded with
/// tester.runAsync and injected into HomePage, as in widget_test.dart.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/history.dart';
import 'package:speakmind/levels.dart';
import 'package:speakmind/main.dart';
import 'package:speakmind/pages/home_page.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/settings.dart';
import 'package:speakmind/theme.dart';

Future<LevelGraph> _loadGraph(WidgetTester tester) async {
  final graph = (await tester.runAsync(() async {
    final raw = await rootBundle.loadString('assets/levels_es.json');
    return LevelGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }))!;
  return graph;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('themes', () {
    test('light theme is light, dark theme is dark', () {
      expect(speakMindTheme().brightness, Brightness.light);
      expect(speakMindDarkTheme().brightness, Brightness.dark);
      expect(
        speakMindDarkTheme().colorScheme.surface,
        SpeakMindColors.darkSurface,
      );
    });

    test('theme mode persists across reloads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await SettingsStore.load();
      expect(store.themeMode, ThemeMode.system);
      await store.setThemeMode(ThemeMode.dark);
      final reloaded = await SettingsStore.load();
      expect(reloaded.themeMode, ThemeMode.dark);
      await reloaded.setThemeMode(ThemeMode.light);
      expect((await SettingsStore.load()).themeMode, ThemeMode.light);
    });
  });

  group('dark mode rendering', () {
    testWidgets('home shell renders under the dark theme', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final progress = await ProgressStore.load();
      final settings = await SettingsStore.load();
      final history = await HistoryStore.load();
      await settings.setThemeMode(ThemeMode.dark);
      final graph = await _loadGraph(tester);
      Brightness? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: speakMindTheme(),
          darkTheme: speakMindDarkTheme(),
          themeMode: settings.themeMode,
          home: Builder(
            builder: (context) {
              seen = Theme.of(context).brightness;
              return HomePage(
                settings: settings,
                progress: progress,
                history: history,
                graph: graph,
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(seen, Brightness.dark);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('世界地图'), findsOneWidget);
    });

    testWidgets('switching theme mode rebuilds the app', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final progress = await ProgressStore.load();
      final settings = await SettingsStore.load();
      final history = await HistoryStore.load();
      await tester.pumpWidget(
        MyApp(settings: settings, progress: progress, history: history),
      );
      // MyApp loads the graph from assets in the test zone, so the home
      // shell stays on its loading spinner here; only the theme switch
      // is under test.
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );
      await settings.setThemeMode(ThemeMode.dark);
      await tester.pump();
      // The ListenableBuilder in MyApp rebuilds MaterialApp with the new
      // themeMode, resolving the dark theme.
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.darkTheme?.brightness, Brightness.dark);
    });
  });
}
