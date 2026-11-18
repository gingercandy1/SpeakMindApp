/// F2 tests: stamps, postcards and stickers (pure functions).
///
/// World stamps come from Boss levels, postcards from finished branch
/// routes and hidden levels, stickers from the 18-achievement catalog.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakmind/levels.dart';
import 'package:speakmind/stamps.dart';

LevelGraph _graph() => LevelGraph.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

Set<String> _stickers({
  Map<String, int> stars = const {},
  Set<String> discoveredHidden = const {},
  Set<String> endingPairs = const {},
  Set<String> postcards = const {},
  int xp = 0,
  int totalStars = 0,
  int noHintClears = 0,
  int streakDays = 0,
}) =>
    evaluateStickers(
      graph: _graph(),
      stars: stars,
      discoveredHidden: discoveredHidden,
      endingPairs: endingPairs,
      postcards: postcards,
      xp: xp,
      totalStars: totalStars,
      noHintClears: noHintClears,
      streakDays: streakDays,
    );

void main() {
  group('world stamps', () {
    test('Boss completion issues the world stamp', () {
      expect(hasWorldStamp({}, 1), isFalse);
      expect(hasWorldStamp({'1-10': 1}, 1), isTrue);
      expect(hasWorldStamp({'1-10': 1}, 2), isFalse);
    });
  });

  group('postcards', () {
    test('a finished branch route earns its postcard', () {
      final graph = _graph();
      expect(
        earnedPostcards(graph: graph, stars: {'1B-1': 1, '1B-2': 1}),
        isEmpty,
      );
      expect(
        earnedPostcards(
          graph: graph,
          stars: {'1B-1': 1, '1B-2': 1, '1B-3': 2},
        ),
        {'route:1:mar'},
      );
    });

    test('a finished hidden level earns its postcard', () {
      final graph = _graph();
      expect(
        earnedPostcards(graph: graph, stars: {'1H-1': 1}),
        {'hidden:1H-1'},
      );
      expect(hiddenPostcardCount({'hidden:1H-1', 'route:1:mar'}), 1);
    });

    test('postcard details carry the level sentences as phrases', () {
      final graph = _graph();
      final card = postcardDetails('hidden:1H-1', graph)!;
      expect(card.titleZh, '秘密小酒窖');
      expect(card.phrases, ['¡Salud!', '¿Qué hay de nuevo?']);
      final route = postcardDetails('route:1:mar', graph)!;
      expect(route.title, 'Ruta del Mar');
      expect(route.phrases, isNotEmpty);
      expect(postcardDetails('route:1:nope', graph), isNull);
      expect(postcardDetails('bogus', graph), isNull);
    });
  });

  group('stickers', () {
    test('catalog has 18 stickers', () {
      expect(stickerCatalog.length, 18);
      expect(
        stickerCatalog.map((s) => s.id).toSet(),
        hasLength(18),
      );
    });

    test('firsts fire on the first of each kind', () {
      expect(_stickers(), isEmpty);
      expect(_stickers(stars: {'1-1': 1}), {'first_steps'});
      expect(
        _stickers(stars: {'1-1': 3}),
        {'first_steps', 'first_three_star'},
      );
      expect(
        _stickers(noHintClears: 1),
        {'first_no_hint'},
      );
      expect(
        _stickers(discoveredHidden: {'1H-1'}),
        {'first_hidden'},
      );
      expect(
        _stickers(endingPairs: {'3-9:recipe'}),
        {'first_ending'},
      );
    });

    test('totals and streaks fire at their thresholds', () {
      expect(
        _stickers(
          stars: {for (var i = 0; i < 10; i++) '1-$i': 3},
          totalStars: 30,
        ),
        contains('ten_three_star'),
      );
      expect(_stickers(xp: 500), contains('xp_500'));
      expect(_stickers(totalStars: 100), contains('stars_100'));
      expect(_stickers(streakDays: 3), contains('streak_3'));
      expect(
        _stickers(streakDays: 7),
        containsAll(['streak_3', 'streak_7']),
      );
      expect(_stickers(noHintClears: 5), contains('five_no_hint'));
      expect(
        _stickers(discoveredHidden: {'a', 'b', 'c', 'd', 'e'}),
        contains('five_hidden'),
      );
    });

    test('world and route stickers need full sets', () {
      final graph = _graph();
      expect(
        _stickers(stars: {'1-10': 1}),
        contains('first_world'),
      );
      expect(
        _stickers(
          postcards: {'route:1:mar'},
        ),
        contains('first_route'),
      );
      // Both routes of W1 finished.
      expect(
        _stickers(
          postcards: {'route:1:mar', 'route:1:ciudad'},
        ),
        containsAll(['first_route', 'both_routes']),
      );
      // All 8 worlds need 8 Boss stars; the sample graph has only W1.
      expect(_stickers(stars: {'1-10': 1}), isNot(contains('all_worlds')));
      expect(graph.worlds.length, 1);
    });
  });
}

const _sampleJson = '''
{
  "lang": "es",
  "version": 1,
  "worlds": [
    {"id": 1, "name": "W1", "name_zh": "世界一", "theme": "问候",
     "cefr": "A1", "grammar": "现在时", "unlock": null}
  ],
  "levels": [
    {"id": "1-1", "kind": "main", "world": 1, "lang": "es",
     "title": "A", "title_zh": "一", "cefr": "A1", "pass_gop": 60, "next": "1-5"},
    {"id": "1-5", "kind": "main", "world": 1, "lang": "es",
     "title": "E", "title_zh": "五", "cefr": "A1", "pass_gop": 60, "next": "1-6",
     "branches": [
       {"route": "mar", "label": "Ruta del Mar", "label_zh": "海边线",
        "levels": ["1B-1", "1B-2", "1B-3"], "rejoin": "1-6"},
       {"route": "ciudad", "label": "Ruta de la Ciudad", "label_zh": "城市线",
        "levels": ["1C-1", "1C-2", "1C-3"], "rejoin": "1-6"}
     ]},
    {"id": "1-6", "kind": "main", "world": 1, "lang": "es",
     "title": "F", "title_zh": "六", "cefr": "A1", "pass_gop": 60, "next": "1-10"},
    {"id": "1-10", "kind": "main", "world": 1, "lang": "es",
     "title": "J", "title_zh": "十", "cefr": "A1", "pass_gop": 60, "next": null},
    {"id": "1B-1", "kind": "branch", "world": 1, "lang": "es",
     "title": "B1", "title_zh": "支一", "cefr": "A1", "pass_gop": 60,
     "route": "mar", "next": "1B-2",
     "sentences": ["Vamos a la playa. — 我们去海滩吧。"]},
    {"id": "1B-2", "kind": "branch", "world": 1, "lang": "es",
     "title": "B2", "title_zh": "支二", "cefr": "A1", "pass_gop": 60,
     "route": "mar", "next": "1B-3",
     "sentences": ["El mar está tranquilo. — 大海很平静。"]},
    {"id": "1B-3", "kind": "branch", "world": 1, "lang": "es",
     "title": "B3", "title_zh": "支三", "cefr": "A1", "pass_gop": 60,
     "route": "mar", "next": "1-6",
     "sentences": ["El barco sale a las diez. — 船十点出发。"]},
    {"id": "1C-1", "kind": "branch", "world": 1, "lang": "es",
     "title": "C1", "title_zh": "城一", "cefr": "A1", "pass_gop": 60,
     "route": "ciudad", "next": "1C-2"},
    {"id": "1C-2", "kind": "branch", "world": 1, "lang": "es",
     "title": "C2", "title_zh": "城二", "cefr": "A1", "pass_gop": 60,
     "route": "ciudad", "next": "1C-3"},
    {"id": "1C-3", "kind": "branch", "world": 1, "lang": "es",
     "title": "C3", "title_zh": "城三", "cefr": "A1", "pass_gop": 60,
     "route": "ciudad", "next": "1-6"},
    {"id": "1H-1", "kind": "hidden", "world": 1, "lang": "es",
     "title": "La bodega secreta", "title_zh": "秘密小酒窖",
     "cefr": "A1", "pass_gop": 60,
     "sentences": ["¡Salud! — 干杯！", "¿Qué hay de nuevo? — 有什么新鲜事？"],
     "hidden_trigger": {"type": "three_star", "level": "1-5"}}
  ]
}
''';
