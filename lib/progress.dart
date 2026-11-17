/// F0: local progress skeleton, persisted in SharedPreferences.
///
/// The unlock set is the source of truth: a level is playable when its id
/// is in the unlocked set. At first launch only `1-1` is unlocked.
/// Stars, XP and discovered hidden levels are stored alongside. F1 adds real
/// completion (stars from gameplay); F2 adds branch choices; F3 adds the
/// hidden-trigger engine. Nothing here needs the server.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'levels.dart';

/// Progress kept on the device. Survives killing the app: everything is
/// written to SharedPreferences on every change.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs);

  static const _unlockedKey = 'progress_unlocked_ids';
  static const _starsKey = 'progress_stars';
  static const _xpKey = 'progress_xp';
  static const _hiddenKey = 'progress_hidden_discovered';

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

  Future<void> _saveUnlocked(Set<String> value) =>
      _prefs.setStringList(_unlockedKey, value.toList());

  Future<void> _saveStars(Map<String, int> value) => _prefs.setStringList(
        _starsKey,
        [for (final e in value.entries) '${e.key}:${e.value}'],
      );

  Future<void> _saveDiscoveredHidden(Set<String> value) =>
      _prefs.setStringList(_hiddenKey, value.toList());

  /// Total XP earned.
  int get xp => _prefs.getInt(_xpKey) ?? 0;

  /// Traveller level: 1 per 100 XP.
  int get travellerLevel => xp ~/ LevelRewards.xpPerLevel + 1;

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

  /// Stars earned in one world (mainline only).
  int worldStars(int worldId, LevelGraph graph) => graph
      .mainlineOfWorld(worldId)
      .fold(0, (sum, l) => sum + stars(l.id));

  /// Total stars earned across all levels.
  int get totalStars =>
      _stars.values.fold(0, (sum, s) => sum + s);

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

  /// Record a completion (F0 test hook; F1 calls this from real gameplay).
  /// Keeps the best star count, awards XP (full on first completion, half
  /// on a replay), and unlocks the next node plus the entry of each branch
  /// route hanging off this node.
  Future<void> completeLevel(
    LevelNode node,
    LevelGraph graph, {
    required int stars,
  }) async {
    final clamped = stars < 0 ? 0 : (stars > 3 ? 3 : stars);
    final firstTime = !isCompleted(node.id);
    final allStars = _stars;
    if (clamped > (allStars[node.id] ?? 0)) {
      allStars[node.id] = clamped;
      await _saveStars(allStars);
    }
    final reward = LevelRewards.forKind(node.kind);
    await _prefs.setInt(_xpKey, xp + (firstTime ? reward : reward ~/ 2));

    final unlocked = _unlocked;
    var changed = false;
    if (node.next != null && unlocked.add(node.next!)) changed = true;
    for (final branch in node.branches ?? const <LevelBranch>[]) {
      if (branch.levels.isNotEmpty && unlocked.add(branch.levels.first)) {
        changed = true;
      }
    }
    if (changed) await _saveUnlocked(unlocked);
    notifyListeners();
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

  /// F0 debug helper: clears all progress back to "only 1-1 unlocked".
  Future<void> reset() async {
    await _prefs.remove(_unlockedKey);
    await _prefs.remove(_starsKey);
    await _prefs.remove(_xpKey);
    await _prefs.remove(_hiddenKey);
    notifyListeners();
  }
}
