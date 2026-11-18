/// F1 tests: W1-W2 mainline content completeness + star/scoring rules.
///
/// Content tests load the shipped `assets/levels_es.json` and check every
/// W1-W2 mainline node has its teaching content filled in the right shape.
/// Scoring tests exercise the pure functions in `lib/level_scoring.dart`.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakmind/level_scoring.dart';
import 'package:speakmind/levels.dart';

Future<LevelGraph> _loadGraph() async {
  final raw = await rootBundle.loadString('assets/levels_es.json');
  return LevelGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W1-W2 mainline content', () {
    late LevelGraph graph;

    setUpAll(() async {
      graph = await _loadGraph();
    });

    test('all 20 W1-W2 mainline nodes have content filled', () {
      final nodes = [
        ...graph.mainlineOfWorld(1),
        ...graph.mainlineOfWorld(2),
      ];
      expect(nodes, hasLength(20));
      for (final node in nodes) {
        expect(node.contentTodo, isFalse, reason: '${node.id} content_todo');
        expect(node.scene, isNotNull, reason: '${node.id} scene');
        expect(node.intro, isNotNull, reason: '${node.id} intro');
        expect(
          node.dialogueOpening,
          isNotNull,
          reason: '${node.id} dialogue_opening',
        );
        expect(node.npcPrompt, isNotNull, reason: '${node.id} npc_prompt');
        expect(node.task, isNotNull, reason: '${node.id} task');
        expect(node.taskRubric, isNotNull, reason: '${node.id} task_rubric');
        expect(
          node.challengePrompt,
          isNotNull,
          reason: '${node.id} challenge_prompt',
        );
        expect(
          node.challengeSentence,
          isNotNull,
          reason: '${node.id} challenge_sentence',
        );
        expect(node.rounds, isNotNull, reason: '${node.id} rounds');
      }
    });

    test('pass lines and rounds match the world', () {
      for (final node in graph.mainlineOfWorld(1)) {
        expect(node.passGop, 60, reason: node.id);
        expect(node.rounds, 4, reason: node.id);
        expect(node.keySounds, contains('ñ'), reason: node.id);
      }
      for (final node in graph.mainlineOfWorld(2)) {
        expect(node.passGop, 65, reason: node.id);
        expect(node.rounds, 5, reason: node.id);
        expect(
          node.keySounds,
          contains('r / rr 对比（只提示）'),
          reason: node.id,
        );
      }
    });

    test('words and sentences use the "es — zh" gloss format', () {
      for (final node in [
        ...graph.mainlineOfWorld(1),
        ...graph.mainlineOfWorld(2),
      ]) {
        expect(
          node.words.length,
          inInclusiveRange(5, 8),
          reason: '${node.id} words',
        );
        expect(
          node.sentences.length,
          inInclusiveRange(2, 3),
          reason: '${node.id} sentences',
        );
        final entries = [...node.words, ...node.sentences];
        final challenge = node.challengeSentence;
        if (challenge != null) entries.add(challenge);
        for (final entry in entries) {
          final gloss = splitGloss(entry);
          expect(gloss.es, isNotEmpty, reason: '${node.id}: $entry');
          expect(gloss.zh, isNotEmpty, reason: '${node.id}: $entry');
        }
      }
    });
  });

  group('level scoring', () {
    test('0 stars when a gate is not met', () {
      expect(
        computeStars(
          dialogueDone: false,
          challengePassed: true,
          challengeExcellent: false,
          pronunciationAvg: 80,
          passGop: 60,
        ),
        0,
      );
      expect(
        computeStars(
          dialogueDone: true,
          challengePassed: false,
          challengeExcellent: false,
          pronunciationAvg: 80,
          passGop: 60,
        ),
        0,
      );
    });

    test('1 star below the pass line, 2 at the line, 3 with excellence', () {
      expect(
        computeStars(
          dialogueDone: true,
          challengePassed: true,
          challengeExcellent: false,
          pronunciationAvg: 59,
          passGop: 60,
        ),
        1,
      );
      expect(
        computeStars(
          dialogueDone: true,
          challengePassed: true,
          challengeExcellent: false,
          pronunciationAvg: 60,
          passGop: 60,
        ),
        2,
      );
      expect(
        computeStars(
          dialogueDone: true,
          challengePassed: true,
          challengeExcellent: true,
          pronunciationAvg: 80,
          passGop: 60,
        ),
        3,
      );
      // An excellent challenge alone does not make 3 stars below the line.
      expect(
        computeStars(
          dialogueDone: true,
          challengePassed: true,
          challengeExcellent: true,
          pronunciationAvg: 50,
          passGop: 60,
        ),
        1,
      );
    });

    test('pronunciation average counts unscored items as 0', () {
      expect(pronunciationAverage([80, 70, null]), closeTo(50, 0.001));
      expect(pronunciationAverage([]), 0);
      expect(pronunciationAverage([90, 90, 90, 90]), 90);
    });

    test('shadowing needs 2 of 3, or all when fewer', () {
      expect(neededShadowPasses(3), 2);
      expect(neededShadowPasses(2), 2);
      expect(neededShadowPasses(1), 1);
    });
  });
}
