/// Widget test: the profile tab's play-history section renders from a
/// prefilled HistoryStore, and tapping a record shows its details.
///
/// Pumps ProfilePage directly (not the whole MyApp): the home shell's
/// IndexedStack builds all four tabs at once, so asserting through it
/// would be noisy. The graph here is a minimal two-level sample, not the
/// shipped asset.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/history.dart';
import 'package:speakmind/levels.dart';
import 'package:speakmind/pages/profile_page.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/settings.dart';
import 'package:speakmind/theme.dart';

Future<HistoryStore> _historyWithRecords() async {
  final history = await HistoryStore.load();
  await history.record(
    levelId: '1-1',
    startedAt: DateTime(2026, 11, 18, 10, 0),
    finishedAt: DateTime(2026, 11, 18, 10, 4),
    stars: 3,
    xpEarned: 20,
    pronAvg: 82.0,
    challengeScore: 92,
    rounds: 4,
    hintsUsed: 1,
    weakestSentence: '¿Dónde está la estación?',
    completed: true,
  );
  await history.record(
    levelId: '1-5',
    startedAt: DateTime(2026, 11, 18, 11, 0),
    finishedAt: DateTime(2026, 11, 18, 11, 2),
    stars: 0,
    xpEarned: 0,
    pronAvg: null,
    challengeScore: null,
    rounds: 2,
    hintsUsed: 0,
    weakestSentence: null,
    completed: false,
  );
  return history;
}

Future<void> _pumpProfile(
  WidgetTester tester,
  HistoryStore history,
) async {
  final progress = await ProgressStore.load();
  final settings = await SettingsStore.load();
  final graph = LevelGraph.fromJson(
    jsonDecode(_sampleJson) as Map<String, dynamic>,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: speakMindTheme(),
      home: ProfilePage(
        graph: graph,
        progress: progress,
        settings: settings,
        history: history,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history section lists recent attempts', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final history = await _historyWithRecords();
    await _pumpProfile(tester, history);

    expect(find.text('游玩记录'), findsOneWidget);
    // Newest first: the abandoned 1-5 attempt, then the completed 1-1.
    expect(find.text('1-1 你好，我是新来的'), findsOneWidget);
    expect(find.text('1-5 ……在哪里'), findsOneWidget);
    expect(find.textContaining('★3'), findsOneWidget);
    expect(find.textContaining('发音 82 分'), findsOneWidget);
    expect(find.textContaining('未完成'), findsOneWidget);
  });

  testWidgets('tapping a record shows its details', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final history = await _historyWithRecords();
    await _pumpProfile(tester, history);

    await tester.tap(find.text('1-1 你好，我是新来的'));
    await tester.pumpAndSettle();

    expect(find.text('¿Dónde está la estación?'), findsOneWidget);
    expect(find.text('提示用了'), findsOneWidget);
    expect(find.text('1 次'), findsOneWidget);
    expect(find.text('对话轮数'), findsOneWidget);
    expect(find.text('4 轮'), findsOneWidget);
    expect(find.text('2026-11-18 10:00'), findsOneWidget);
    expect(find.text('2026-11-18 10:04'), findsOneWidget);
  });

  testWidgets('empty history shows the empty state', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final history = await HistoryStore.load();
    await _pumpProfile(tester, history);

    expect(find.text('游玩记录'), findsOneWidget);
    expect(
      find.text('还没有游玩记录，打一关就会出现在这里。'),
      findsOneWidget,
    );
  });
}

const _sampleJson = '''
{
  "lang": "es",
  "version": 1,
  "worlds": [
    {"id": 1, "name": "¡Hola, Madrid!", "name_zh": "马德里初到",
     "theme": "问候", "cefr": "A1", "grammar": "现在时",
     "guide_npc": "Carmen", "unlock": null}
  ],
  "levels": [
    {"id": "1-1", "kind": "main", "world": 1, "lang": "es",
     "title": "¡Hola! Soy nuevo", "title_zh": "你好，我是新来的",
     "cefr": "A1", "pass_gop": 60, "next": "1-5"},
    {"id": "1-5", "kind": "main", "world": 1, "lang": "es",
     "title": "¿Dónde está...?", "title_zh": "……在哪里",
     "cefr": "A1", "pass_gop": 60, "next": null}
  ]
}
''';
