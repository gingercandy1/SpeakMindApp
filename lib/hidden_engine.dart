/// F3: hidden-level trigger engine (pure Dart, no Flutter).
///
/// Every trigger declared in `assets/levels_es.json` (`hidden_trigger`) is
/// evaluated on-device from data the app already has: stars, hints used,
/// pronunciation average, dialogue turns, endings picked, and stamp counts.
/// The server is never involved. Evaluation is idempotent — already
/// discovered hidden levels are never reported twice.
///
/// Triggers handled here (completion-driven):
/// `three_star`, `no_hint`, `no_hint_gop`, `dialogue_choice`,
/// `over_challenge`, `challenge_excellent`, `collect`, `all_mainline`.
/// `map_tap` and `revisit` are UI-driven (a tap on the map / reopening a
/// completed level) — see [hiddenForMapTap] / [hiddenForRevisit].
library;

import 'levels.dart';

/// What happened when a level finished (or a dialogue choice was picked).
class CompletionEvent {
  const CompletionEvent({
    required this.levelId,
    required this.stars,
    this.hintsUsed = 0,
    this.pronunciationAvg = 0,
    this.userTurns = 0,
    this.roundsTarget = 0,
    this.challengeExcellent = false,
    this.endingId,
    this.isReplay = false,
  });

  /// The level that was completed (or where the choice was picked).
  final String levelId;

  /// Stars earned in this completion (0 = gates not met).
  final int stars;

  /// How many hints the user asked for during the level.
  final int hintsUsed;

  /// Mean GOP of the scored spoken items (0 when nothing was scored).
  final double pronunciationAvg;

  /// User turns spoken in the dialogue step.
  final int userTurns;

  /// Dialogue rounds the level asks for.
  final int roundsTarget;

  /// Whether the challenge sentence scored "excellent" (GOP >= 90).
  final bool challengeExcellent;

  /// Ending id picked at a dialogue branch point, if any.
  final String? endingId;

  /// True when the level had already been completed before.
  final bool isReplay;
}

/// Hidden levels whose trigger matches [event] (and the stored progress),
/// excluding ones already in [discoveredHidden]. When [onlyTypes] is
/// given, only triggers of those types are considered (used when a dialogue
/// choice is picked mid-level: only `dialogue_choice` may fire there).
List<String> evaluateHiddenTriggers({
  required LevelGraph graph,
  required Map<String, int> stars,
  required Set<String> discoveredHidden,
  required int hiddenPostcards,
  required CompletionEvent event,
  Set<String>? onlyTypes,
}) {
  if (event.stars < 1 && event.endingId == null) return const [];
  final found = <String>[];
  for (final node in graph.levels) {
    if (node.kind != LevelKind.hidden) continue;
    if (discoveredHidden.contains(node.id)) continue;
    final trigger = node.hiddenTrigger;
    if (trigger == null) continue;
    if (onlyTypes != null && !onlyTypes.contains(trigger.type)) continue;
    if (_matches(trigger, graph, stars, hiddenPostcards, event)) {
      found.add(node.id);
    }
  }
  return found;
}

bool _matches(
  HiddenTrigger trigger,
  LevelGraph graph,
  Map<String, int> stars,
  int hiddenPostcards,
  CompletionEvent event,
) {
  switch (trigger.type) {
    case 'three_star':
      return trigger.level == event.levelId && event.stars == 3;
    case 'no_hint':
      return trigger.level == event.levelId && event.hintsUsed == 0;
    case 'no_hint_gop':
      return trigger.level == event.levelId &&
          event.hintsUsed == 0 &&
          event.pronunciationAvg >= 80;
    case 'dialogue_choice':
      return trigger.level == event.levelId &&
          event.endingId != null &&
          (trigger.ending == null || trigger.ending == event.endingId);
    case 'over_challenge':
      final needed = trigger.count ?? event.roundsTarget + 1;
      return trigger.level == event.levelId && event.userTurns >= needed;
    case 'challenge_excellent':
      return trigger.level == event.levelId && event.challengeExcellent;
    case 'collect':
      return hiddenPostcards >= (trigger.count ?? 5);
    case 'all_mainline':
      return graph.levels
          .where((l) => l.kind == LevelKind.main)
          .every((l) => (stars[l.id] ?? 0) >= 1);
    case 'map_tap':
    case 'revisit':
      // UI-driven, never matched by a completion event.
      return false;
    default:
      return false;
  }
}

/// The hidden level a map easter-egg point in [worldId] reveals, if any
/// is still undiscovered there.
LevelNode? hiddenForMapTap(LevelGraph graph, int worldId,
    Set<String> discoveredHidden) {
  for (final node in graph.hiddenOfWorld(worldId)) {
    if (node.hiddenTrigger?.type == 'map_tap' &&
        !discoveredHidden.contains(node.id)) {
      return node;
    }
  }
  return null;
}

/// The hidden level a revisit of [levelId] reveals: reopening a completed
/// level that a `revisit` trigger is attached to. Returns null when the
/// level was never completed or the hidden level is already discovered.
LevelNode? hiddenForRevisit(LevelGraph graph, String levelId,
    Map<String, int> stars, Set<String> discoveredHidden) {
  if ((stars[levelId] ?? 0) < 1) return null;
  for (final node in graph.levels) {
    if (node.kind != LevelKind.hidden) continue;
    final trigger = node.hiddenTrigger;
    if (trigger?.type == 'revisit' &&
        trigger?.level == levelId &&
        !discoveredHidden.contains(node.id)) {
      return node;
    }
  }
  return null;
}

/// Levels whose revisit opens a hidden level (for the envelope marker on
/// the map): completed levels with a `revisit` trigger attached.
List<String> revisitSourceLevels(LevelGraph graph) => [
      for (final node in graph.levels)
        if (node.kind == LevelKind.hidden &&
            node.hiddenTrigger?.type == 'revisit' &&
            node.hiddenTrigger?.level != null)
          node.hiddenTrigger!.level!,
    ];
