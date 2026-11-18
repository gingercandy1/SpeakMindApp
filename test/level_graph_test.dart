/// F0 tests: graph parsing, shipped JSON structure, and ProgressStore
/// unlock / star / hidden / persistence behaviour.
///
/// These are unit/widget tests (flutter_test). The shipped-JSON test loads
/// `assets/levels_es.json` from the test bundle, so the JSON must be
/// registered in pubspec.yaml for it to run.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/levels.dart';
import 'package:speakmind/progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LevelGraph parsing', () {
    test('parses worlds and nodes from JSON', () {
      final graph = LevelGraph.fromJson(
        jsonDecode(_sampleJson) as Map<String, dynamic>,
      );
      expect(graph.worlds.length, 2);
      expect(graph.totalLevels, 5);
      expect(graph.countByKind(LevelKind.main), 3);
      expect(graph.countByKind(LevelKind.branch), 1);
      expect(graph.countByKind(LevelKind.hidden), 1);
      final fork = graph.levelById('1-5')!;
      expect(fork.isFork, isTrue);
      expect(fork.branches, hasLength(1));
      expect(fork.branches!.first.levels, ['1B-1', '1B-2']);
      expect(fork.branches!.first.rejoin, '1-6');
      expect(graph.nextOf(fork)?.id, '1-6');
      final hidden = graph.levelById('1H-1')!;
      expect(hidden.kind, LevelKind.hidden);
      expect(hidden.hiddenTrigger?.type, 'three_star');
    });

    test('shipped assets/levels_es.json has 138 nodes, refs resolve', () async {
      final raw = await rootBundle.loadString('assets/levels_es.json');
      final graph = LevelGraph.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(graph.worlds.length, 8);
      expect(graph.totalLevels, 138);
      expect(graph.countByKind(LevelKind.main), 80);
      expect(graph.countByKind(LevelKind.branch), 42);
      expect(graph.countByKind(LevelKind.hidden), 16);
      for (final level in graph.levels) {
        if (level.next != null) {
          expect(graph.levelById(level.next!), isNotNull,
              reason: '${level.id} next -> ${level.next}');
        }
        for (final branch in level.branches ?? const <LevelBranch>[]) {
          for (final id in branch.levels) {
            expect(graph.levelById(id), isNotNull,
                reason: '${level.id} branch -> $id');
          }
          expect(graph.levelById(branch.rejoin), isNotNull,
              reason: '${level.id} rejoin -> ${branch.rejoin}');
        }
        final trigger = level.hiddenTrigger;
        if (trigger?.level != null) {
          expect(graph.levelById(trigger!.level!), isNotNull,
              reason: '${level.id} trigger -> ${trigger.level}');
        }
      }
      // Every world: 10 mainline + 2 hidden (+ 6 branch from W2).
      for (var w = 1; w <= 8; w++) {
        expect(graph.mainlineOfWorld(w).length, 10, reason: 'W$w mainline');
        expect(graph.hiddenOfWorld(w).length, 2, reason: 'W$w hidden');
        expect(graph.branchesOfWorld(w).length, w >= 2 ? 6 : 0,
            reason: 'W$w branches');
      }
    });
  });

  group('ProgressStore', () {
    late ProgressStore store;
    late LevelGraph graph;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = await ProgressStore.load();
      graph = LevelGraph.fromJson(
        jsonDecode(_sampleJson) as Map<String, dynamic>,
      );
    });

    test('defaults to only 1-1 unlocked, no stars, no XP', () {
      expect(store.isUnlocked('1-1'), isTrue);
      expect(store.isUnlocked('1-2'), isFalse);
      expect(store.stars('1-1'), 0);
      expect(store.xp, 0);
      expect(store.travellerLevel, 1);
    });

    test('completing a fork unlocks next only; branch entry needs a pick',
        () async {
      final node = graph.levelById('1-5')!;
      await store.completeLevel(node, graph, stars: 3);
      expect(store.stars('1-5'), 3);
      expect(store.xp, LevelRewards.mainline);
      expect(store.isUnlocked('1-6'), isTrue);
      // F2 rule: finishing the fork does NOT auto-unlock branch entries.
      expect(store.isUnlocked('1B-1'), isFalse);
      // Picking the route unlocks its first level; first pick wins.
      expect(await store.chooseBranch('1-5', 'mar', graph), isTrue);
      expect(store.branchChoice('1-5'), 'mar');
      expect(store.isUnlocked('1B-1'), isTrue);
      expect(await store.chooseBranch('1-5', 'mar', graph), isFalse);
    });

    test('replay keeps best stars and awards half XP', () async {
      final node = graph.levelById('1-1')!;
      await store.completeLevel(node, graph, stars: 2);
      await store.completeLevel(node, graph, stars: 1);
      expect(store.stars('1-1'), 2);
      expect(
        store.xp,
        LevelRewards.mainline + LevelRewards.mainline ~/ 2,
      );
    });

    test('hidden level is invisible until discovered', () async {
      final hidden = graph.levelById('1H-1')!;
      expect(store.isVisible(hidden, graph), isFalse);
      await store.discoverHidden('1H-1');
      expect(store.isVisible(hidden, graph), isTrue);
      expect(store.isUnlocked('1H-1'), isTrue);
    });

    test('world unlock rule: W2 opens after W1 mainline >= 8 stars',
        () async {
      // Sample graph has only W1/W2 with 3 mainline levels in W1; the
      // rule needs 8, so W2 must stay locked here.
      expect(store.isWorldUnlocked(2, graph), isFalse);
      expect(store.isWorldUnlocked(1, graph), isTrue);
    });

    test('progress survives reload (SharedPreferences)', () async {
      await store.completeLevel(graph.levelById('1-1')!, graph, stars: 3);
      final reloaded = await ProgressStore.load();
      // 1-1's next in the sample is 1-5 (not 1-2): that is what unlocks.
      expect(reloaded.isUnlocked('1-5'), isTrue);
      expect(reloaded.stars('1-1'), 3);
      expect(reloaded.xp, LevelRewards.mainline);
    });

    test('reset returns to only 1-1 unlocked', () async {
      await store.completeLevel(graph.levelById('1-1')!, graph, stars: 3);
      await store.reset();
      expect(store.isUnlocked('1-1'), isTrue);
      expect(store.isUnlocked('1-2'), isFalse);
      expect(store.xp, 0);
    });
  });
}

const _sampleJson = '''
{
  "lang": "es",
  "version": 1,
  "worlds": [
    {"id": 1, "name": "¡Hola, Madrid!", "name_zh": "马德里初到",
     "theme": "问候", "cefr": "A1", "grammar": "现在时",
     "guide_npc": "Carmen", "unlock": null},
    {"id": 2, "name": "Barcelona y el Mar", "name_zh": "巴塞罗那",
     "theme": "旅行", "cefr": "A1-A2", "grammar": "ir a + 不定式",
     "guide_npc": "Pablo",
     "unlock": {"requires_world": 1, "min_mainline_stars": 8}}
  ],
  "levels": [
    {"id": "1-1", "kind": "main", "world": 1, "lang": "es",
     "title": "¡Hola! Soy nuevo", "title_zh": "你好，我是新来的",
     "cefr": "A1", "pass_gop": 60, "next": "1-5"},
    {"id": "1-5", "kind": "main", "world": 1, "lang": "es",
     "title": "¿Dónde está...?", "title_zh": "……在哪里",
     "cefr": "A1", "pass_gop": 60, "next": "1-6",
     "branches": [{"route": "mar", "label": "Ruta del Mar",
       "label_zh": "海边线", "levels": ["1B-1", "1B-2"], "rejoin": "1-6"}]},
    {"id": "1B-1", "kind": "branch", "world": 1, "lang": "es",
     "title": "Ruta del Mar · 1", "title_zh": "海边线 · 第 1 关",
     "cefr": "A1", "pass_gop": 60, "route": "mar", "next": "1B-2"},
    {"id": "1-6", "kind": "main", "world": 1, "lang": "es",
     "title": "Nos vemos", "title_zh": "回头见",
     "cefr": "A1", "pass_gop": 60, "next": null},
    {"id": "1H-1", "kind": "hidden", "world": 1, "lang": "es",
     "title": "La bodega secreta", "title_zh": "秘密小酒窖",
     "cefr": "A1", "pass_gop": 60,
     "hidden_trigger": {"type": "three_star", "level": "1-5"}}
  ]
}
''';
