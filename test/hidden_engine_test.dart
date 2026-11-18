/// F3 tests: hidden-trigger engine (pure function).
///
/// Every trigger type in the shipped JSON is exercised against a small
/// graph: three_star, no_hint, no_hint_gop, dialogue_choice,
/// over_challenge, challenge_excellent, collect, all_mainline, plus the
/// UI-driven map_tap / revisit lookups.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakmind/hidden_engine.dart';
import 'package:speakmind/levels.dart';

LevelGraph _graph() => LevelGraph.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

List<String> _eval(
  LevelGraph graph,
  Map<String, int> stars,
  CompletionEvent event, {
  Set<String> discovered = const {},
  int hiddenPostcards = 0,
}) =>
    evaluateHiddenTriggers(
      graph: graph,
      stars: stars,
      discoveredHidden: discovered,
      hiddenPostcards: hiddenPostcards,
      event: event,
    );

void main() {
  group('completion-driven triggers', () {
    test('three_star fires only on a 3-star finish of its level', () {
      final graph = _graph();
      expect(
        _eval(graph, {}, const CompletionEvent(levelId: '1-5', stars: 3)),
        ['1H-1'],
      );
      expect(
        _eval(graph, {}, const CompletionEvent(levelId: '1-5', stars: 2)),
        isEmpty,
      );
      expect(
        _eval(graph, {}, const CompletionEvent(levelId: '1-6', stars: 3)),
        isEmpty,
      );
    });

    test('no_hint fires on a zero-hint finish, any stars', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '2-6', stars: 1, hintsUsed: 0),
        ),
        ['2H-1'],
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '2-6', stars: 2, hintsUsed: 1),
        ),
        isEmpty,
      );
    });

    test('no_hint_gop needs zero hints and 80+ pronunciation', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '5-1',
            stars: 2,
            hintsUsed: 0,
            pronunciationAvg: 80,
          ),
        ),
        ['5H-2'],
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '5-1',
            stars: 2,
            hintsUsed: 0,
            pronunciationAvg: 79,
          ),
        ),
        isEmpty,
      );
    });

    test('dialogue_choice matches the ending id', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '3-9',
            stars: 2,
            endingId: 'recipe',
          ),
        ),
        ['3H-1'],
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '3-9',
            stars: 2,
            endingId: 'normal',
          ),
        ),
        isEmpty,
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '3-9', stars: 2),
        ),
        isEmpty,
      );
    });

    test('over_challenge fires past the trigger count', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '5-6',
            stars: 2,
            userTurns: 8,
            roundsTarget: 6,
          ),
        ),
        ['5H-1'],
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '5-6',
            stars: 2,
            userTurns: 7,
            roundsTarget: 6,
          ),
        ),
        isEmpty,
      );
    });

    test('challenge_excellent fires on an excellent challenge', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(
            levelId: '7-1',
            stars: 3,
            challengeExcellent: true,
          ),
        ),
        ['7H-1'],
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '7-1', stars: 3),
        ),
        isEmpty,
      );
    });

    test('collect fires at five hidden postcards', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '8-1', stars: 1),
          hiddenPostcards: 5,
        ),
        ['8H-1'],
      );
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '8-1', stars: 1),
          hiddenPostcards: 4,
        ),
        isEmpty,
      );
    });

    test('all_mainline fires only when every mainline level is done', () {
      final graph = _graph();
      // The sample graph has 11 mainline levels; starring all of them
      // satisfies "every mainline level has >= 1 star".
      final stars = {
        '1-1': 1, '1-5': 1, '1-6': 1, '1-10': 1, '2-6': 1, '3-9': 1,
        '4-9': 1, '5-1': 1, '5-6': 1, '7-1': 1, '8-1': 1,
      };
      expect(
        _eval(graph, stars, const CompletionEvent(levelId: '1-10', stars: 1)),
        ['8H-2'],
      );
      expect(
        _eval(
          graph,
          {'1-1': 1, '1-5': 1, '1-6': 1},
          const CompletionEvent(levelId: '1-6', stars: 1),
        ),
        isEmpty,
      );
    });

    test('already discovered hidden levels never fire twice', () {
      final graph = _graph();
      expect(
        _eval(
          graph,
          {},
          const CompletionEvent(levelId: '1-5', stars: 3),
          discovered: {'1H-1'},
        ),
        isEmpty,
      );
    });

    test('a failed completion (0 stars) fires nothing', () {
      final graph = _graph();
      expect(
        _eval(graph, {}, const CompletionEvent(levelId: '1-5', stars: 0)),
        isEmpty,
      );
    });
  });

  group('UI-driven triggers', () {
    test('map_tap lookup finds the egg point of a world', () {
      final graph = _graph();
      expect(hiddenForMapTap(graph, 2, {} )?.id, '2H-2');
      expect(hiddenForMapTap(graph, 2, {'2H-2'}), isNull);
      expect(hiddenForMapTap(graph, 1, {}), isNull);
    });

    test('revisit lookup needs a completed source level', () {
      final graph = _graph();
      expect(hiddenForRevisit(graph, '4-9', {'4-9': 1}, {})?.id, '4H-1');
      expect(hiddenForRevisit(graph, '4-9', {}, {}), isNull);
      expect(
        hiddenForRevisit(graph, '4-9', {'4-9': 1}, {'4H-1'}),
        isNull,
      );
    });

    test('revisitSourceLevels lists the levels with a letter waiting', () {
      expect(revisitSourceLevels(_graph()), ['4-9']);
    });
  });
}

const _sampleJson = '''
{
  "lang": "es",
  "version": 1,
  "worlds": [
    {"id": 1, "name": "W1", "name_zh": "世界一", "theme": "问候",
     "cefr": "A1", "grammar": "现在时", "unlock": null},
    {"id": 2, "name": "W2", "name_zh": "世界二", "theme": "旅行",
     "cefr": "A1-A2", "grammar": "ir a", "unlock": null},
    {"id": 3, "name": "W3", "name_zh": "世界三", "theme": "集市",
     "cefr": "A2", "grammar": "过去时", "unlock": null},
    {"id": 4, "name": "W4", "name_zh": "世界四", "theme": "安第斯",
     "cefr": "A2-B1", "grammar": "过去时对比", "unlock": null},
    {"id": 5, "name": "W5", "name_zh": "世界五", "theme": "探戈",
     "cefr": "B1", "grammar": "虚拟式", "unlock": null},
    {"id": 7, "name": "W7", "name_zh": "世界七", "theme": "影城",
     "cefr": "B1-B2", "grammar": "虚拟式", "unlock": null},
    {"id": 8, "name": "W8", "name_zh": "世界八", "theme": "环球",
     "cefr": "B2", "grammar": "综合", "unlock": null}
  ],
  "levels": [
    {"id": "1-1", "kind": "main", "world": 1, "lang": "es",
     "title": "A", "title_zh": "一", "cefr": "A1", "pass_gop": 60, "next": "1-5"},
    {"id": "1-5", "kind": "main", "world": 1, "lang": "es",
     "title": "E", "title_zh": "五", "cefr": "A1", "pass_gop": 60, "next": "1-6"},
    {"id": "1-6", "kind": "main", "world": 1, "lang": "es",
     "title": "F", "title_zh": "六", "cefr": "A1", "pass_gop": 60, "next": "1-10"},
    {"id": "1-10", "kind": "main", "world": 1, "lang": "es",
     "title": "J", "title_zh": "十", "cefr": "A1", "pass_gop": 60, "next": null},
    {"id": "2-6", "kind": "main", "world": 2, "lang": "es",
     "title": "K", "title_zh": "十一", "cefr": "A1-A2", "pass_gop": 65, "next": null},
    {"id": "3-9", "kind": "main", "world": 3, "lang": "es",
     "title": "L", "title_zh": "十二", "cefr": "A2", "pass_gop": 70, "next": null},
    {"id": "4-9", "kind": "main", "world": 4, "lang": "es",
     "title": "M", "title_zh": "十三", "cefr": "A2-B1", "pass_gop": 70, "next": null},
    {"id": "5-1", "kind": "main", "world": 5, "lang": "es",
     "title": "N", "title_zh": "十四", "cefr": "B1", "pass_gop": 70, "next": null},
    {"id": "5-6", "kind": "main", "world": 5, "lang": "es",
     "title": "O", "title_zh": "十五", "cefr": "B1", "pass_gop": 70, "next": null},
    {"id": "7-1", "kind": "main", "world": 7, "lang": "es",
     "title": "P", "title_zh": "十六", "cefr": "B1-B2", "pass_gop": 75, "next": null},
    {"id": "8-1", "kind": "main", "world": 8, "lang": "es",
     "title": "Q", "title_zh": "十七", "cefr": "B2", "pass_gop": 75, "next": null},
    {"id": "1H-1", "kind": "hidden", "world": 1, "lang": "es",
     "title": "H1", "title_zh": "藏一", "cefr": "A1", "pass_gop": 60,
     "hidden_trigger": {"type": "three_star", "level": "1-5"}},
    {"id": "2H-1", "kind": "hidden", "world": 2, "lang": "es",
     "title": "H2", "title_zh": "藏二", "cefr": "A1-A2", "pass_gop": 65,
     "hidden_trigger": {"type": "no_hint", "level": "2-6"}},
    {"id": "2H-2", "kind": "hidden", "world": 2, "lang": "es",
     "title": "H3", "title_zh": "藏三", "cefr": "A1-A2", "pass_gop": 65,
     "hidden_trigger": {"type": "map_tap", "level": "2-6"}},
    {"id": "3H-1", "kind": "hidden", "world": 3, "lang": "es",
     "title": "H4", "title_zh": "藏四", "cefr": "A2", "pass_gop": 70,
     "hidden_trigger": {"type": "dialogue_choice", "level": "3-9", "ending": "recipe"}},
    {"id": "4H-1", "kind": "hidden", "world": 4, "lang": "es",
     "title": "H5", "title_zh": "藏五", "cefr": "A2-B1", "pass_gop": 70,
     "hidden_trigger": {"type": "revisit", "level": "4-9"}},
    {"id": "5H-1", "kind": "hidden", "world": 5, "lang": "es",
     "title": "H6", "title_zh": "藏六", "cefr": "B1", "pass_gop": 70,
     "hidden_trigger": {"type": "over_challenge", "level": "5-6", "count": 8}},
    {"id": "5H-2", "kind": "hidden", "world": 5, "lang": "es",
     "title": "H7", "title_zh": "藏七", "cefr": "B1", "pass_gop": 70,
     "hidden_trigger": {"type": "no_hint_gop", "level": "5-1"}},
    {"id": "7H-1", "kind": "hidden", "world": 7, "lang": "es",
     "title": "H8", "title_zh": "藏八", "cefr": "B1-B2", "pass_gop": 75,
     "hidden_trigger": {"type": "challenge_excellent", "level": "7-1"}},
    {"id": "8H-1", "kind": "hidden", "world": 8, "lang": "es",
     "title": "H9", "title_zh": "藏九", "cefr": "B2", "pass_gop": 75,
     "hidden_trigger": {"type": "collect", "count": 5}},
    {"id": "8H-2", "kind": "hidden", "world": 8, "lang": "es",
     "title": "H10", "title_zh": "藏十", "cefr": "B2", "pass_gop": 75,
     "hidden_trigger": {"type": "all_mainline"}}
  ]
}
''';
