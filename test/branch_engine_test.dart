/// F2 tests: branch engine rules in ProgressStore.
///
/// Fork completion no longer auto-unlocks branch entries (F0 did); the
/// user picks a route on the branch page, the first pick wins, and the
/// other route opens for a revisit once its world is complete.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/levels.dart';
import 'package:speakmind/progress.dart';

LevelGraph _graph() => LevelGraph.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

Future<ProgressStore> _store() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return ProgressStore.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('branch choices', () {
    test('fork completion unlocks next only, not branch entries', () async {
      final store = await _store();
      final graph = _graph();
      await store.completeLevel(graph.levelById('1-5')!, graph, stars: 3);
      expect(store.isUnlocked('1-6'), isTrue);
      expect(store.isUnlocked('1B-1'), isFalse);
      expect(store.isUnlocked('1C-1'), isFalse);
    });

    test('chooseBranch unlocks the chosen route first level only', () async {
      final store = await _store();
      final graph = _graph();
      expect(await store.chooseBranch('1-5', 'mar', graph), isTrue);
      expect(store.branchChoice('1-5'), 'mar');
      expect(store.isUnlocked('1B-1'), isTrue);
      expect(store.isUnlocked('1C-1'), isFalse);
      // First pick wins.
      expect(await store.chooseBranch('1-5', 'ciudad', graph), isFalse);
      expect(store.branchChoice('1-5'), 'mar');
    });

    test('chooseBranch rejects a non-fork and an unknown route', () async {
      final store = await _store();
      final graph = _graph();
      expect(await store.chooseBranch('1-1', 'mar', graph), isFalse);
      expect(await store.chooseBranch('1-5', 'nope', graph), isFalse);
      expect(await store.chooseBranch('9-9', 'mar', graph), isFalse);
    });

    test('branch nodes unlock in route order and rejoin the mainline',
        () async {
      final store = await _store();
      final graph = _graph();
      await store.chooseBranch('1-5', 'mar', graph);
      await store.completeLevel(graph.levelById('1B-1')!, graph, stars: 2);
      expect(store.isUnlocked('1B-2'), isTrue);
      expect(store.isUnlocked('1B-3'), isFalse);
      await store.completeLevel(graph.levelById('1B-2')!, graph, stars: 2);
      expect(store.isUnlocked('1B-3'), isTrue);
      await store.completeLevel(graph.levelById('1B-3')!, graph, stars: 2);
      expect(store.isUnlocked('1-6'), isTrue);
    });

    test('world completion opens the unchosen route for a revisit',
        () async {
      final store = await _store();
      final graph = _graph();
      await store.chooseBranch('1-5', 'mar', graph);
      expect(store.isUnlocked('1C-1'), isFalse);
      // Complete every mainline level of W1.
      for (final id in ['1-1', '1-2', '1-3', '1-4', '1-5', '1-6', '1-7',
          '1-8', '1-9', '1-10']) {
        await store.completeLevel(graph.levelById(id)!, graph, stars: 1);
      }
      expect(store.isWorldComplete(1, graph), isTrue);
      expect(store.isUnlocked('1C-1'), isTrue);
    });

    test('branch choices survive reload', () async {
      final store = await _store();
      final graph = _graph();
      await store.chooseBranch('1-5', 'ciudad', graph);
      final reloaded = await ProgressStore.load();
      expect(reloaded.branchChoice('1-5'), 'ciudad');
      expect(reloaded.isUnlocked('1C-1'), isTrue);
    });
  });
}

const _sampleJson = '''
{
  "lang": "es",
  "version": 1,
  "worlds": [
    {"id": 1, "name": "W1", "name_zh": "世界一",
     "theme": "问候", "cefr": "A1", "grammar": "现在时",
     "guide_npc": "Carmen", "unlock": null}
  ],
  "levels": [
    {"id": "1-1", "kind": "main", "world": 1, "lang": "es",
     "title": "A", "title_zh": "一", "cefr": "A1", "pass_gop": 60, "next": "1-2"},
    {"id": "1-2", "kind": "main", "world": 1, "lang": "es",
     "title": "B", "title_zh": "二", "cefr": "A1", "pass_gop": 60, "next": "1-3"},
    {"id": "1-3", "kind": "main", "world": 1, "lang": "es",
     "title": "C", "title_zh": "三", "cefr": "A1", "pass_gop": 60, "next": "1-4"},
    {"id": "1-4", "kind": "main", "world": 1, "lang": "es",
     "title": "D", "title_zh": "四", "cefr": "A1", "pass_gop": 60, "next": "1-5"},
    {"id": "1-5", "kind": "main", "world": 1, "lang": "es",
     "title": "E", "title_zh": "五", "cefr": "A1", "pass_gop": 60, "next": "1-6",
     "branches": [
       {"route": "mar", "label": "Ruta del Mar", "label_zh": "海边线",
        "levels": ["1B-1", "1B-2", "1B-3"], "rejoin": "1-6"},
       {"route": "ciudad", "label": "Ruta de la Ciudad", "label_zh": "城市线",
        "levels": ["1C-1", "1C-2", "1C-3"], "rejoin": "1-6"}
     ]},
    {"id": "1-6", "kind": "main", "world": 1, "lang": "es",
     "title": "F", "title_zh": "六", "cefr": "A1", "pass_gop": 60, "next": "1-7"},
    {"id": "1-7", "kind": "main", "world": 1, "lang": "es",
     "title": "G", "title_zh": "七", "cefr": "A1", "pass_gop": 60, "next": "1-8"},
    {"id": "1-8", "kind": "main", "world": 1, "lang": "es",
     "title": "H", "title_zh": "八", "cefr": "A1", "pass_gop": 60, "next": "1-9"},
    {"id": "1-9", "kind": "main", "world": 1, "lang": "es",
     "title": "I", "title_zh": "九", "cefr": "A1", "pass_gop": 60, "next": "1-10"},
    {"id": "1-10", "kind": "main", "world": 1, "lang": "es",
     "title": "J", "title_zh": "十", "cefr": "A1", "pass_gop": 60, "next": null},
    {"id": "1B-1", "kind": "branch", "world": 1, "lang": "es",
     "title": "B1", "title_zh": "支一", "cefr": "A1", "pass_gop": 60,
     "route": "mar", "next": "1B-2"},
    {"id": "1B-2", "kind": "branch", "world": 1, "lang": "es",
     "title": "B2", "title_zh": "支二", "cefr": "A1", "pass_gop": 60,
     "route": "mar", "next": "1B-3"},
    {"id": "1B-3", "kind": "branch", "world": 1, "lang": "es",
     "title": "B3", "title_zh": "支三", "cefr": "A1", "pass_gop": 60,
     "route": "mar", "next": "1-6"},
    {"id": "1C-1", "kind": "branch", "world": 1, "lang": "es",
     "title": "C1", "title_zh": "城一", "cefr": "A1", "pass_gop": 60,
     "route": "ciudad", "next": "1C-2"},
    {"id": "1C-2", "kind": "branch", "world": 1, "lang": "es",
     "title": "C2", "title_zh": "城二", "cefr": "A1", "pass_gop": 60,
     "route": "ciudad", "next": "1C-3"},
    {"id": "1C-3", "kind": "branch", "world": 1, "lang": "es",
     "title": "C3", "title_zh": "城三", "cefr": "A1", "pass_gop": 60,
     "route": "ciudad", "next": "1-6"}
  ]
}
''';
