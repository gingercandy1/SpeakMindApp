/// F0-F3: local progress, persisted in SharedPreferences.
///
/// The unlock set is the source of truth: a level is playable when its id
/// is in the unlocked set. At first launch only `1-1` is unlocked.
/// Stars, XP, discovered hidden levels, branch choices, dialogue endings,
/// stickers and streaks are stored alongside. F2 adds branch choices and
/// stamps; F3 adds the hidden-trigger engine. Nothing here needs the server.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hidden_engine.dart';
import 'levels.dart';
import 'stamps.dart';

/// What a level completion produced, for the results screen to announce:
/// newly discovered hidden levels, newly earned postcards and stickers.
class CompletionOutcome {
  const CompletionOutcome({
    required this.stars,
    required this.earnedXp,
    this.newlyDiscoveredHidden = const [],
    this.newPostcards = const [],
    this.newStickers = const [],
  });

  /// Stars earned in this completion.
  final int stars;

  /// XP awarded (full on first completion, half on a replay).
  final int earnedXp;

  /// Hidden level ids discovered by this completion.
  final List<String> newlyDiscoveredHidden;

  /// Postcard ids earned by this completion.
  final List<String> newPostcards;

  /// Sticker ids earned by this completion.
  final List<String> newStickers;
}

/// Progress kept on the device. Survives killing the app: everything is
/// written to SharedPreferences on every change.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs);

  static const _unlockedKey = 'progress_unlocked_ids';
  static const _starsKey = 'progress_stars';
  static const _xpKey = 'progress_xp';
  static const _hiddenKey = 'progress_hidden_discovered';
  static const _branchChoicesKey = 'progress_branch_choices';
  static const _endingsKey = 'progress_endings';
  static const _stickersKey = 'progress_stickers';
  static const _noHintKey = 'progress_no_hint_clears';
  static const _streakKey = 'progress_streak_days';
  static const _lastPlayedKey = 'progress_last_played';

  /// The first level. Nothing else is unlocked at first launch.
  static const String firstLevelId = '1-1';

  final SharedPreferences _prefs;

  static Future<ProgressStore> load() async =>
      ProgressStore(await SharedPreferences.getInstance());

  Set<String> get _unlocked =>
      _prefs.getStringList(_unlockedKey)?.toSet() ?? {firstLevelId};

  Map<String, int> get _stars {
    final out = <String, int>{};
    for (final entry in _prefs.getStringList(_starsKey) ?? const <String>[]) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        out[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    return out;
  }

  Set<String> get _discoveredHidden =>
      _prefs.getStringList(_hiddenKey)?.toSet() ?? {};

  Map<String, String> _stringMap(String key) {
    final out = <String, String>{};
    for (final entry in _prefs.getStringList(key) ?? const <String>[]) {
      final i = entry.indexOf(':');
      if (i > 0) out[entry.substring(0, i)] = entry.substring(i + 1);
    }
    return out;
  }

  Future<void> _saveStringMap(String key, Map<String, String> value) =>
      _prefs.setStringList(
        key,
        [for (final e in value.entries) '${e.key}:${e.value}'],
      );

  Future<void> _saveUnlocked(Set<String> value) =>
      _prefs.setStringList(_unlockedKey, value.toList());

  Future<void> _saveStars(Map<String, int> value) => _prefs.setStringList(
        _starsKey,
        [for (final e in value.entries) '${e.key}:${e.value}'],
      );

  Future<void> _saveDiscoveredHidden(Set<String> value) =>
      _prefs.setStringList(_hiddenKey, value.toList());

  Future<void> _saveStickers(Set<String> value) =>
      _prefs.setStringList(_stickersKey, value.toList());

  /// Total XP earned.
  int get xp => _prefs.getInt(_xpKey) ?? 0;

  /// Traveller level: 1 per 100 XP.
  int get travellerLevel => xp ~/ LevelRewards.xpPerLevel + 1;

  /// Stars by level id (for the trigger/stamp engines).
  Map<String, int> get starsById => _stars;

  /// Discovered hidden level ids.
  Set<String> get discoveredHiddenIds => _discoveredHidden;

  /// Branch route chosen at each fork: `{forkId: routeCode}`.
  /// First pick wins; the other route stays locked until its world is
  /// complete, then it opens for a revisit.
  Map<String, String> get branchChoices => _stringMap(_branchChoicesKey);

  /// Route chosen at [forkId], or null when no route is picked yet.
  String? branchChoice(String forkId) => branchChoices[forkId];

  /// Dialogue endings found, as `levelId:endingId` pairs. One level can
  /// hold several endings (replaying it and picking the other side finds
  /// another one — the results screen says so).
  Set<String> get endingPairs =>
      _prefs.getStringList(_endingsKey)?.toSet() ?? {};

  /// Endings found on [levelId].
  Set<String> endingsFor(String levelId) => {
        for (final pair in endingPairs)
          if (pair.startsWith('$levelId:')) pair.substring(levelId.length + 1),
      };

  /// Whether [levelId] already has [endingId] recorded.
  bool hasEnding(String levelId, String endingId) =>
      endingPairs.contains('$levelId:$endingId');

  /// Stickers earned so far.
  Set<String> get earnedStickerIds =>
      _prefs.getStringList(_stickersKey)?.toSet() ?? {};

  /// Zero-hint clears, for the sticker achievements.
  int get noHintClears => _prefs.getInt(_noHintKey) ?? 0;

  /// Consecutive learning days (today counts once played).
  int get streakDays => _prefs.getInt(_streakKey) ?? 0;

  /// Whether [levelId] is unlocked (in the unlock set).
  bool isUnlocked(String levelId) => _unlocked.contains(levelId);

  /// Stars earned on [levelId] (0-3, 0 = not completed).
  int stars(String levelId) => _stars[levelId] ?? 0;

  /// Whether [levelId] has been completed at least once.
  bool isCompleted(String levelId) => stars(levelId) > 0;

  /// Whether a hidden level has been discovered (and so shows on the map).
  bool isHiddenDiscovered(String levelId) =>
      _discoveredHidden.contains(levelId);

  /// A hidden node is visible on the map only after discovery.
  bool isVisible(LevelNode node, LevelGraph graph) {
    if (node.kind == LevelKind.hidden) {
      return isHiddenDiscovered(node.id);
    }
    return true;
  }

  /// Whether a world is reached: W1 is always open; later worlds open when
  /// the previous world has enough mainline levels at >= 1 star (see the
  /// `unlock` rule in levels_es.json).
  bool isWorldUnlocked(int worldId, LevelGraph graph) {
    final world = graph.worldById(worldId);
    if (world.isOpenByDefault) return true;
    final prev = world.unlockRequiresWorld!;
    final needed = world.unlockMinMainlineStars ?? 0;
    final got = graph
        .mainlineOfWorld(prev)
        .where((l) => stars(l.id) >= 1)
        .length;
    return got >= needed;
  }

  /// Whether every mainline level of [worldId] is complete (Boss done).
  bool isWorldComplete(int worldId, LevelGraph graph) => graph
      .mainlineOfWorld(worldId)
      .every((l) => stars(l.id) >= 1);

  /// Stars earned in one world (mainline only).
  int worldStars(int worldId, LevelGraph graph) => graph
      .mainlineOfWorld(worldId)
      .fold(0, (sum, l) => sum + stars(l.id));

  /// Total stars earned across all levels.
  int get totalStars =>
      _stars.values.fold(0, (sum, s) => sum + s);

  /// Mainline progress: (completed, total) over the 80 mainline levels.
  (int, int) mainlineProgress(LevelGraph graph) {
    final main = graph.levels.where((l) => l.kind == LevelKind.main);
    return (
      main.where((l) => stars(l.id) >= 1).length,
      main.length,
    );
  }

  /// Exploration progress: (done, total) over branch levels completed +
  /// hidden levels completed + dialogue endings found. The five trigger
  /// endings are the countable endings; postcards and stickers are the
  /// rewards for this progress, not part of the count.
  (int, int) explorationProgress(LevelGraph graph) {
    final branch = graph.levels.where((l) => l.kind == LevelKind.branch);
    final hidden = graph.levels.where((l) => l.kind == LevelKind.hidden);
    final done = branch.where((l) => stars(l.id) >= 1).length +
        hidden.where((l) => stars(l.id) >= 1).length +
        endingPairs.length;
    return (done, branch.length + hidden.length + 5);
  }

  /// Postcards earned, computed from stars (see stamps.dart).
  Set<String> postcards(LevelGraph graph) =>
      earnedPostcards(graph: graph, stars: _stars);

  /// Stickers earned, computed from all progress state.
  Set<String> stickers(LevelGraph graph) => evaluateStickers(
        graph: graph,
        stars: _stars,
        discoveredHidden: _discoveredHidden,
        endingPairs: endingPairs,
        postcards: postcards(graph),
        xp: xp,
        totalStars: totalStars,
        noHintClears: noHintClears,
        streakDays: streakDays,
      );

  /// The level the "继续" button should open: the first unlocked mainline
  /// level that is not completed yet, or the last unlocked one.
  LevelNode? currentLevel(LevelGraph graph) {
    LevelNode? fallback;
    for (final level in graph.levels) {
      if (level.kind != LevelKind.main) continue;
      if (!isUnlocked(level.id)) continue;
      fallback = level;
      if (!isCompleted(level.id)) return level;
    }
    return fallback;
  }

  /// Pick a branch route at a fork (first pick wins). Unlocks the route's
  /// first level. Returns true when the choice was recorded.
  Future<bool> chooseBranch(
    String forkId,
    String route,
    LevelGraph graph,
  ) async {
    final fork = graph.levelById(forkId);
    if (fork == null || !fork.isFork) return false;
    final choices = branchChoices;
    if (choices.containsKey(forkId)) return false;
    final branches = fork.branches!;
    LevelBranch? branch;
    for (final b in branches) {
      if (b.route == route) branch = b;
    }
    if (branch == null || branch.levels.isEmpty) return false;
    choices[forkId] = route;
    await _saveStringMap(_branchChoicesKey, choices);
    final unlocked = _unlocked;
    if (unlocked.add(branch.levels.first)) {
      await _saveUnlocked(unlocked);
    }
    notifyListeners();
    return true;
  }

  /// Record a dialogue ending. Runs the `dialogue_choice` hidden triggers
  /// for this level right away, so a discovery lands the moment the choice
  /// is picked. Returns newly discovered hidden level ids.
  Future<List<String>> recordEnding(
    String levelId,
    String endingId,
    LevelGraph graph,
  ) async {
    final found = <String>[];
    final pairs = endingPairs;
    final isNew = pairs.add('$levelId:$endingId');
    if (isNew) {
      await _prefs.setStringList(_endingsKey, pairs.toList());
    }
    final discovered = evaluateHiddenTriggers(
      graph: graph,
      stars: _stars,
      discoveredHidden: _discoveredHidden,
      hiddenPostcards: hiddenPostcardCount(postcards(graph)),
      event: CompletionEvent(
        levelId: levelId,
        stars: stars(levelId),
        endingId: endingId,
      ),
      onlyTypes: const {'dialogue_choice'},
    );
    for (final id in discovered) {
      await discoverHidden(id);
      found.add(id);
    }
    if (isNew || found.isNotEmpty) notifyListeners();
    return found;
  }

  /// Revisit check: reopening a completed level that a `revisit` trigger
  /// is attached to discovers its hidden level. Returns the discovered id
  /// or null. Call when a level page opens.
  Future<String?> checkRevisit(LevelNode node, LevelGraph graph) async {
    final hidden = hiddenForRevisit(
      graph,
      node.id,
      _stars,
      _discoveredHidden,
    );
    if (hidden == null) return null;
    await discoverHidden(hidden.id);
    return hidden.id;
  }

  /// Map easter-egg tap: discover the `map_tap` hidden level of a world.
  /// Returns the discovered id or null when there is none left there.
  Future<String?> discoverMapEgg(int worldId, LevelGraph graph) async {
    final hidden = hiddenForMapTap(graph, worldId, _discoveredHidden);
    if (hidden == null) return null;
    await discoverHidden(hidden.id);
    return hidden.id;
  }

  /// Record a completion: keeps the best star count, awards XP (full on
  /// first completion, half on a replay), unlocks the next node, runs the
  /// hidden-trigger engine and the stamp/sticker evaluation, and unlocks
  /// the unchosen branch route when its world completes. Fork completion
  /// no longer auto-unlocks branch entries — the user picks a route on the
  /// branch page (F2 rule: first pick counts, the other route is a revisit).
  Future<CompletionOutcome> completeLevel(
    LevelNode node,
    LevelGraph graph, {
    required int stars,
    int hintsUsed = 0,
    double pronunciationAvg = 0,
    int userTurns = 0,
    bool challengeExcellent = false,
    String? endingId,
  }) async {
    final clamped = stars < 0 ? 0 : (stars > 3 ? 3 : stars);
    final firstTime = !isCompleted(node.id);
    final postcardsBefore = postcards(graph);
    final stickersBefore = earnedStickerIds;

    final allStars = _stars;
    if (clamped > (allStars[node.id] ?? 0)) {
      allStars[node.id] = clamped;
      await _saveStars(allStars);
    }
    final reward = LevelRewards.forKind(node.kind);
    final earnedXp = firstTime ? reward : reward ~/ 2;
    await _prefs.setInt(_xpKey, xp + earnedXp);

    if (clamped >= 1 && hintsUsed == 0) {
      await _prefs.setInt(_noHintKey, noHintClears + 1);
    }
    await _touchStreak();
    if (endingId != null) {
      final pairs = endingPairs;
      if (pairs.add('${node.id}:$endingId')) {
        await _prefs.setStringList(_endingsKey, pairs.toList());
      }
    }

    final unlocked = _unlocked;
    var changed = false;
    if (node.next != null && unlocked.add(node.next!)) changed = true;
    // A world just completed opens the unchosen branch route for revisit.
    if (node.kind == LevelKind.main && isWorldComplete(node.world, graph)) {
      for (final fork in graph.mainlineOfWorld(node.world)) {
        if (!fork.isFork) continue;
        for (final branch in fork.branches ?? const <LevelBranch>[]) {
          if (branch.levels.isNotEmpty &&
              unlocked.add(branch.levels.first)) {
            changed = true;
          }
        }
      }
    }
    if (changed) await _saveUnlocked(unlocked);

    // Hidden triggers + stamps, evaluated on the saved state.
    final postcardsAfter = postcards(graph);
    final discovered = evaluateHiddenTriggers(
      graph: graph,
      stars: _stars,
      discoveredHidden: _discoveredHidden,
      hiddenPostcards: hiddenPostcardCount(postcardsAfter),
      event: CompletionEvent(
        levelId: node.id,
        stars: clamped,
        hintsUsed: hintsUsed,
        pronunciationAvg: pronunciationAvg,
        userTurns: userTurns,
        roundsTarget: node.rounds ?? 4,
        challengeExcellent: challengeExcellent,
        endingId: endingId,
        isReplay: !firstTime,
      ),
    );
    for (final id in discovered) {
      await discoverHidden(id);
    }
    final stickersAfter = stickers(graph);
    final newStickers =
        stickersAfter.difference(stickersBefore).toList()..sort();
    if (newStickers.isNotEmpty) {
      await _saveStickers(stickersAfter);
    }
    final newPostcards =
        postcardsAfter.difference(postcardsBefore).toList()..sort();
    notifyListeners();
    return CompletionOutcome(
      stars: clamped,
      earnedXp: earnedXp,
      newlyDiscoveredHidden: discovered,
      newPostcards: newPostcards,
      newStickers: newStickers,
    );
  }

  /// Mark a hidden level as discovered: it appears on the map and unlocks.
  Future<void> discoverHidden(String levelId) async {
    final discovered = _discoveredHidden;
    final unlocked = _unlocked;
    var changed = false;
    if (discovered.add(levelId)) changed = true;
    if (unlocked.add(levelId)) changed = true;
    if (changed) {
      await _saveDiscoveredHidden(discovered);
      await _saveUnlocked(unlocked);
    }
    notifyListeners();
  }

  /// Daily streak: same day keeps it, yesterday extends it by one, a gap
  /// restarts it at one. Only the completion path calls this.
  Future<void> _touchStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastRaw = _prefs.getString(_lastPlayedKey);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    final lastDay = last == null
        ? null
        : DateTime(last.year, last.month, last.day);
    var streak = streakDays;
    if (lastDay == null || today.difference(lastDay).inDays > 1) {
      streak = 1;
    } else if (today.difference(lastDay).inDays == 1) {
      streak = streak + 1;
    }
    await _prefs.setInt(_streakKey, streak);
    await _prefs.setString(_lastPlayedKey, today.toIso8601String());
  }

  /// F0 debug helper: clears all progress back to "only 1-1 unlocked".
  Future<void> reset() async {
    await _prefs.remove(_unlockedKey);
    await _prefs.remove(_starsKey);
    await _prefs.remove(_xpKey);
    await _prefs.remove(_hiddenKey);
    await _prefs.remove(_branchChoicesKey);
    await _prefs.remove(_endingsKey);
    await _prefs.remove(_stickersKey);
    await _prefs.remove(_noHintKey);
    await _prefs.remove(_streakKey);
    await _prefs.remove(_lastPlayedKey);
    notifyListeners();
  }
}
