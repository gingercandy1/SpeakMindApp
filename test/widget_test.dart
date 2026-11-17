// Smoke test: the app boots to the world map tab.
//
// Replaces the old Flutter template counter test: MyApp now takes the
// loaded SettingsStore and ProgressStore (F0), and there is no counter
// in the app any more.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speakmind/main.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/settings.dart';

void main() {
  testWidgets('app boots to the map tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = await ProgressStore.load();
    final settings = await SettingsStore.load();
    await tester.pumpWidget(MyApp(settings: settings, progress: progress));
    // First pump shows the loading spinner while LevelGraph.load() runs;
    // the next pump renders the loaded home shell with the bottom nav.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Do not assert on the nav labels' text: IndexedStack builds all four
    // tabs at once, and StampsPage/ProfilePage reuse '邮票册'/'我的' as
    // their AppBar titles, so those strings appear twice on screen.
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('世界地图'), findsOneWidget);
    expect(find.textContaining('马德里初到'), findsOneWidget);
  });
}
