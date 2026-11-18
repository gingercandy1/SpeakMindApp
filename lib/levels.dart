/// F0: level graph data model, driven by `assets/levels_es.json`.
///
/// The graph is the single source of truth for the 138 nodes (80 mainline +
/// 42 branch + 16 hidden). F1 filled the teaching content of the W1-W2
/// mainline levels (words, sentences, npc_prompt, task, dialogue_opening,
/// intro, challenge); the other 118 nodes keep `content_todo: true` until
/// their phase. See the levels dev doc §8 for the field contract.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

/// Kind of a level node: mainline, branch route, or hidden.
enum LevelKind { main, branch, hidden }

LevelKind _kindFrom(String? value) => switch (value) {
      'branch' => LevelKind.branch,
      'hidden' => LevelKind.hidden,
      _ => LevelKind.main,
    };

/// One branch route hanging off a fork node (the level-5 node of W2-W8).
class LevelBranch {
  const LevelBranch({
    required this.route,
    required this.label,
    required this.labelZh,
    required this.levels,
    required this.rejoin,
  });

  /// Route code, e.g. `mar`.
  final String route;

  /// Spanish label, e.g. `Ruta del Mar`.
  final String label;

  /// Chinese label, e.g. `海边线`.
  final String labelZh;

  /// Level ids on this route, in order, e.g. `2B-1..2B-3`.
  final List<String> levels;

  /// Mainline level the route rejoins, e.g. `2-6`.
  final String rejoin;

  factory LevelBranch.fromJson(Map<String, dynamic> j) => LevelBranch(
        route: j['route'] as String,
        label: j['label'] as String,
        labelZh: j['label_zh'] as String? ?? '',
        levels: [for (final l in (j['levels'] as List? ?? const [])) l as String],
        rejoin: j['rejoin'] as String,
      );
}

/// How a hidden level is discovered. All evaluation happens on-device
/// (F3 builds the trigger engine); F0 only stores the declaration.
class HiddenTrigger {
  const HiddenTrigger({required this.type, this.level, this.note});

  /// e.g. `three_star`, `no_hint`, `dialogue_choice`, `map_tap`,
  /// `revisit`, `over_challenge`, `no_hint_gop`, `challenge_excellent`,
  /// `collect`, `all_mainline`.
  final String type;

  /// The level the trigger is attached to, when there is one.
  final String? level;

  /// Human-readable condition, in Chinese.
  final String? note;

  factory HiddenTrigger.fromJson(Map<String, dynamic> j) => HiddenTrigger(
        type: j['type'] as String,
        level: j['level'] as String?,
        note: j['note'] as String?,
      );
}

/// One world on the travel map.
class WorldInfo {
  const WorldInfo({
    required this.id,
    required this.name,
    required this.nameZh,
    required this.theme,
    required this.cefr,
    required this.grammar,
    this.guideNpc,
    this.unlockRequiresWorld,
    this.unlockMinMainlineStars,
  });

  /// 1-8.
  final int id;

  /// Spanish name, e.g. `¡Hola, Madrid!`.
  final String name;

  /// Chinese name, e.g. `马德里初到`.
  final String nameZh;

  /// Theme / scenes, in Chinese.
  final String theme;

  /// CEFR band, e.g. `A1`, `B1-B2`.
  final String cefr;

  /// Grammar anchor for this world, in Chinese.
  final String grammar;

  /// Guide NPC for this world, when one is named (Carmen / Pablo / Don José).
  final String? guideNpc;

  /// Previous world that must be far enough along, or null (W1 is open).
  final int? unlockRequiresWorld;

  /// How many mainline levels of that world need >= 1 star to open this one.
  final int? unlockMinMainlineStars;

  bool get isOpenByDefault => unlockRequiresWorld == null;

  factory WorldInfo.fromJson(Map<String, dynamic> j) {
    final unlock = j['unlock'] as Map<String, dynamic>?;
    return WorldInfo(
      id: j['id'] as int,
      name: j['name'] as String,
      nameZh: j['name_zh'] as String? ?? '',
      theme: j['theme'] as String? ?? '',
      cefr: j['cefr'] as String? ?? '',
      grammar: j['grammar'] as String? ?? '',
      guideNpc: j['guide_npc'] as String?,
      unlockRequiresWorld: unlock?['requires_world'] as int?,
      unlockMinMainlineStars: unlock?['min_mainline_stars'] as int?,
    );
  }
}

/// Splits a content entry written as `es — zh` (Spanish text, em-dash,
/// Chinese gloss) into its two parts. Entries without the separator are
/// returned whole as [Gloss.es] with an empty [Gloss.zh].
({String es, String zh}) splitGloss(String entry) {
  final i = entry.indexOf(' — ');
  if (i < 0) return (es: entry, zh: '');
  return (es: entry.substring(0, i).trim(), zh: entry.substring(i + 3).trim());
}

/// One node of the level graph.
class LevelNode {
  const LevelNode({
    required this.id,
    required this.kind,
    required this.world,
    required this.title,
    required this.titleZh,
    this.scene,
    this.intro,
    this.dialogueOpening,
    required this.cefr,
    required this.passGop,
    this.rounds,
    required this.keySounds,
    required this.words,
    required this.sentences,
    this.npcPrompt,
    this.task,
    this.taskRubric,
    this.challengePrompt,
    this.challengeSentence,
    this.next,
    this.branches,
    this.hiddenTrigger,
    this.route,
    required this.contentTodo,
  });

  /// e.g. `1-1`, `2B-1`, `1H-1`.
  final String id;

  final LevelKind kind;

  /// World number 1-8.
  final int world;

  /// Spanish title.
  final String title;

  /// Chinese title.
  final String titleZh;

  /// Scene description, in Chinese. Null until F1 fills it in.
  final String? scene;

  /// Brasa's story intro for step 1, in Chinese. Null until F1.
  final String? intro;

  /// The NPC's first Spanish line in the dialogue, spoken by TTS.
  /// Null until F1.
  final String? dialogueOpening;

  /// CEFR band of this level's world.
  final String cefr;

  /// GOP pass line for this level's world (60 / 70 / 75).
  final int passGop;

  /// Dialogue rounds. Null until F1 fills it in.
  final int? rounds;

  /// Key sounds for this level (e.g. rr, ñ). Empty until F1.
  final List<String> keySounds;

  /// Target words. Empty until F1.
  final List<String> words;

  /// Core sentences. Empty until F1.
  final List<String> sentences;

  /// NPC persona prompt for /chat. Null until F1.
  final String? npcPrompt;

  /// Challenge task. Null until F1.
  final String? task;

  /// Challenge rubric. Null until F1.
  final String? taskRubric;

  /// Step-5 variant-task instruction, in Chinese. Null until F1.
  final String? challengePrompt;

  /// Step-5 sentence to speak, written as `es — zh`. Null until F1.
  final String? challengeSentence;

  /// Next node on the mainline path, or null for the final level.
  final String? next;

  /// Branch routes hanging off this node (only level-5 nodes of W2-W8).
  final List<LevelBranch>? branches;

  /// Discovery condition (hidden nodes only).
  final HiddenTrigger? hiddenTrigger;

  /// Branch route code, for branch nodes only.
  final String? route;

  /// True while the per-level teaching content is still unwritten (F1+).
  final bool contentTodo;

  /// `true` for the 10th (Boss) mainline level of a world.
  bool get isBoss => kind == LevelKind.main && id.endsWith('-10');

  /// `true` for a level-5 mainline node that opens a fork.
  bool get isFork => branches != null && branches!.isNotEmpty;

  factory LevelNode.fromJson(Map<String, dynamic> j) => LevelNode(
        id: j['id'] as String,
        kind: _kindFrom(j['kind'] as String?),
        world: j['world'] as int,
        title: j['title'] as String? ?? '',
        titleZh: j['title_zh'] as String? ?? '',
        scene: j['scene'] as String?,
        intro: j['intro'] as String?,
        dialogueOpening: j['dialogue_opening'] as String?,
        cefr: j['cefr'] as String? ?? '',
        passGop: j['pass_gop'] as int? ?? 60,
        rounds: j['rounds'] as int?,
        keySounds: [
          for (final s in (j['key_sounds'] as List? ?? const [])) s as String,
        ],
        words: [
          for (final w in (j['words'] as List? ?? const [])) w as String,
        ],
        sentences: [
          for (final s in (j['sentences'] as List? ?? const [])) s as String,
        ],
        npcPrompt: j['npc_prompt'] as String?,
        task: j['task'] as String?,
        taskRubric: j['task_rubric'] as String?,
        challengePrompt: j['challenge_prompt'] as String?,
        challengeSentence: j['challenge_sentence'] as String?,
        next: j['next'] as String?,
        branches: (j['branches'] as List?)
            ?.map((b) => LevelBranch.fromJson(b as Map<String, dynamic>))
            .toList(),
        hiddenTrigger: j['hidden_trigger'] == null
            ? null
            : HiddenTrigger.fromJson(
                j['hidden_trigger'] as Map<String, dynamic>,
              ),
        route: j['route'] as String?,
        contentTodo: j['content_todo'] == true,
      );
}

/// XP rewards (final planning doc,定稿数值).
class LevelRewards {
  LevelRewards._();

  static const int mainline = 20;
  static const int branch = 12;
  static const int hidden = 30;

  /// XP for a first completion of a node of this kind.
  static int forKind(LevelKind kind) => switch (kind) {
        LevelKind.main => mainline,
        LevelKind.branch => branch,
        LevelKind.hidden => hidden,
      };

  /// XP needed to go up one traveller level.
  static const int xpPerLevel = 100;
}

/// The whole level graph: 8 worlds, 138 nodes.
class LevelGraph {
  LevelGraph({required this.worlds, required this.levels})
      : _byId = {for (final l in levels) l.id: l};

  final List<WorldInfo> worlds;
  final List<LevelNode> levels;
  final Map<String, LevelNode> _byId;

  /// Loads `assets/levels_es.json` (registered in pubspec.yaml).
  static Future<LevelGraph> load() async {
    final raw = await rootBundle.loadString('assets/levels_es.json');
    return LevelGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory LevelGraph.fromJson(Map<String, dynamic> j) => LevelGraph(
        worlds: [
          for (final w in (j['worlds'] as List? ?? const []))
            WorldInfo.fromJson(w as Map<String, dynamic>),
        ],
        levels: [
          for (final l in (j['levels'] as List? ?? const []))
            LevelNode.fromJson(l as Map<String, dynamic>),
        ],
      );

  LevelNode? levelById(String id) => _byId[id];

  WorldInfo worldById(int id) =>
      worlds.firstWhere((w) => w.id == id, orElse: () => worlds.first);

  List<LevelNode> levelsOfWorld(int worldId, {LevelKind? kind}) => [
        for (final l in levels)
          if (l.world == worldId && (kind == null || l.kind == kind)) l,
      ];

  List<LevelNode> mainlineOfWorld(int worldId) =>
      levelsOfWorld(worldId, kind: LevelKind.main);

  List<LevelNode> branchesOfWorld(int worldId) =>
      levelsOfWorld(worldId, kind: LevelKind.branch);

  List<LevelNode> hiddenOfWorld(int worldId) =>
      levelsOfWorld(worldId, kind: LevelKind.hidden);

  /// The node after [node] on the mainline path, or null.
  LevelNode? nextOf(LevelNode node) =>
      node.next == null ? null : _byId[node.next];

  int get totalLevels => levels.length;

  int countByKind(LevelKind kind) =>
      levels.where((l) => l.kind == kind).length;
}
