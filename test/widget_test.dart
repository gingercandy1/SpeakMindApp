// Smoke test: the app boots to the world map tab.
//
// Replaces the old Flutter template counter test: MyApp now takes the
// loaded SettingsStore and ProgressStore (F0), and there is no counter
// in the app any more.
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
    expect(find.text('地图'), findsOneWidget);
    expect(find.text('邮票册'), findsOneWidget);
    expect(find.text('练习场'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
