// Smoke test: the home shell shows the world map tab with the bottom nav.
//
// Replaces the old Flutter template counter test: MyApp now takes the
// loaded SettingsStore and ProgressStore (F0), and there is no counter
// in the app any more.
//
// The graph is preloaded with rootBundle and injected into HomePage:
// pumping the whole MyApp and waiting for its FutureBuilder to load the
// graph from assets never completed in the CI widget-test environment
// (the bottom nav never appeared after 20 pumped frames), even though
// the same load works when awaited directly in a test.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speakmind/levels.dart';
import 'package:speakmind/pages/home_page.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/settings.dart';
import 'package:speakmind/theme.dart';

void main() {
  testWidgets('home shell shows the map tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = await ProgressStore.load();
    final settings = await SettingsStore.load();
    final graph = LevelGraph.fromJson(
      jsonDecode(await rootBundle.loadString('assets/levels_es.json'))
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: speakMindTheme(),
        home: HomePage(settings: settings, progress: progress, graph: graph),
      ),
    );
    // The injected graph is already loaded (Future.value), so one pump
    // renders the loaded shell; a second pump covers the rebuild.
    await tester.pump();
    await tester.pump();
    // Do not assert on the nav labels' text: IndexedStack builds all four
    // tabs at once, and StampsPage/ProfilePage reuse '邮票册'/'我的' as
    // their AppBar titles, so those strings appear twice on screen.
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('世界地图'), findsOneWidget);
    expect(find.textContaining('马德里初到'), findsOneWidget);
  });
}
