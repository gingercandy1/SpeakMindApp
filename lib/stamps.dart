/// F2: stamps, postcards and Chispa stickers (pure Dart, no Flutter).
///
/// Rules (final planning doc p.6):
/// * World stamp (8): completing a world's Boss level (X-10).
/// * Scene postcard: completing a whole branch route (3 levels) or a hidden
///   level. The doc says 24 postcards; the graph has 14 routes + 16 hidden
///   levels = 30 postcards, so the book holds 30 — the doc's 24 does not
///   reconcile with 42 branch + 16 hidden levels.
/// * Chispa sticker (18): achievements — firsts, streaks, totals.
///
/// Everything here is computed from progress state, so nothing extra needs
/// storing except the counters ProgressStore keeps (zero-hint clears,
/// streak). "Newly earned" is found by diffing the computed sets before
/// and after a completion.
library;

import 'levels.dart';

/// A world's Boss level is complete, so its world stamp is issued.
bool hasWorldStamp(Map<String, int> stars, int worldId) =>
    (stars['$worldId-10'] ?? 0) >= 1;

/// Postcard ids: `route:<world>:<route>` for a finished branch route,
/// `hidden:<hiddenId>` for a finished hidden level.
Set<String> earnedPostcards({
  required LevelGraph graph,
  required Map<String, int> stars,
}) {
  final out = <String>{};
  for (final level in graph.levels) {
    if (level.kind != LevelKind.main || !level.isFork) continue;
    for (final route in level.branches ?? const <LevelBranch>[]) {
      final done = route.levels
          .every((id) => (stars[graph.levelById(id)?.id ?? ''] ?? 0) >= 1);
      if (done) out.add('route:${level.world}:${route.route}');
    }
  }
  for (final hidden in graph.levels.where((l) => l.kind == LevelKind.hidden)) {
    if ((stars[hidden.id] ?? 0) >= 1) out.add('hidden:${hidden.id}');
  }
  return out;
}

/// How many special-edition (hidden) postcards have been earned — the
/// `collect` hidden trigger counts these.
int hiddenPostcardCount(Set<String> postcards) =>
    postcards.where((id) => id.startsWith('hidden:')).length;

/// One postcard in the book, with the three authentic phrases on its back
/// (taken from the level's core sentences, so they can be listened to).
class Postcard {
  const Postcard({
    required this.id,
    required this.title,
    required this.titleZh,
    required this.worldId,
    required this.phrases,
  });

  /// `route:<world>:<route>` or `hidden:<hiddenId>`.
  final String id;

  /// Spanish title (route label or hidden level title).
  final String title;

  /// Chinese title.
  final String titleZh;

  /// World the postcard belongs to.
  final int worldId;

  /// Spanish phrases on the back (the level's core sentences).
  final List<String> phrases;
}

/// Display data for a postcard id, or null when the id is unknown.
Postcard? postcardDetails(String id, LevelGraph graph) {
  if (id.startsWith('route:')) {
    final parts = id.split(':');
    if (parts.length != 3) return null;
    final worldId = int.tryParse(parts[1]);
    final routeCode = parts[2];
    if (worldId == null) return null;
    for (final level in graph.mainlineOfWorld(worldId)) {
      for (final route in level.branches ?? const <LevelBranch>[]) {
        if (route.route != routeCode) continue;
        final last = route.levels.isEmpty
            ? null
            : graph.levelById(route.levels.last);
        return Postcard(
          id: id,
          title: route.label,
          titleZh: '${route.labelZh} · ${graph.worldById(worldId).nameZh}',
          worldId: worldId,
          phrases: [
            for (final s in (last?.sentences ?? const []))
              splitGloss(s).es,
          ],
        );
      }
    }
    return null;
  }
  if (id.startsWith('hidden:')) {
    final level = graph.levelById(id.substring('hidden:'.length));
    if (level == null) return null;
    return Postcard(
      id: id,
      title: level.title,
      titleZh: level.titleZh,
      worldId: level.world,
      phrases: [for (final s in level.sentences) splitGloss(s).es],
    );
  }
  return null;
}

/// One Chispa sticker: an achievement with a name and how to earn it.
class Sticker {
  const Sticker({
    required this.id,
    required this.name,
    required this.how,
  });

  /// Stable id, e.g. `first_three_star`.
  final String id;

  /// Chinese name shown in the book.
  final String name;

  /// Chinese condition text (also shown while locked).
  final String how;
}

/// The 18-sticker catalog (final planning doc p.6).
const List<Sticker> stickerCatalog = [
  Sticker(id: 'first_steps', name: '第一步', how: '完成任意 1 关'),
  Sticker(id: 'first_three_star', name: '三星新手', how: '首次拿到 3 星'),
  Sticker(id: 'ten_three_star', name: '三星猎手', how: '累计 10 关拿到 3 星'),
  Sticker(id: 'first_no_hint', name: '零提示', how: '首次零提示通关'),
  Sticker(id: 'five_no_hint', name: '胸有成竹', how: '累计 5 次零提示通关'),
  Sticker(id: 'first_hidden', name: '发现者', how: '发现第一个隐藏关'),
  Sticker(id: 'five_hidden', name: '寻宝家', how: '发现 5 个隐藏关'),
  Sticker(id: 'first_route', name: '岔路客', how: '完成第一条支线'),
  Sticker(id: 'both_routes', name: '两条路都走', how: '同一个世界的两条支线都完成'),
  Sticker(id: 'first_world', name: '世界征服者', how: '完成第一个世界'),
  Sticker(id: 'three_worlds', name: '环游新手', how: '完成 3 个世界'),
  Sticker(id: 'all_worlds', name: '环球旅人', how: '完成全部 8 个世界'),
  Sticker(id: 'first_ending', name: '另一个结局', how: '发现第一个对话结局'),
  Sticker(id: 'three_endings', name: '故事收集者', how: '发现 3 个对话结局'),
  Sticker(id: 'streak_3', name: '三天不辍', how: '连续学习 3 天'),
  Sticker(id: 'streak_7', name: '一周坚持', how: '连续学习 7 天'),
  Sticker(id: 'xp_500', name: '经验达人', how: '累计获得 500 XP'),
  Sticker(id: 'stars_100', name: '百星闪耀', how: '累计获得 100 颗星'),
];

/// Which stickers the given progress state has earned.
Set<String> evaluateStickers({
  required LevelGraph graph,
  required Map<String, int> stars,
  required Set<String> discoveredHidden,
  required Set<String> endingPairs,
  required Set<String> postcards,
  required int xp,
  required int totalStars,
  required int noHintClears,
  required int streakDays,
}) {
  final earned = <String>{};
  final anyDone = stars.values.any((s) => s >= 1);
  final threeStarCount = stars.values.where((s) => s == 3).length;
  final worldStamps =
      [for (var w = 1; w <= 8; w++) w].where((w) => hasWorldStamp(stars, w)).length;
  final routePostcards =
      postcards.where((id) => id.startsWith('route:')).length;
  final bothRoutes = [for (var w = 1; w <= 8; w++) w].any((w) {
    final routes = graph.mainlineOfWorld(w)
        .expand((l) => l.branches ?? const <LevelBranch>[])
        .map((b) => 'route:$w:${b.route}');
    return routes.every(postcards.contains) && routes.isNotEmpty;
  });

  void addIf(String id, bool earnedIt) {
    if (earnedIt) earned.add(id);
  }

  addIf('first_steps', anyDone);
  addIf('first_three_star', threeStarCount >= 1);
  addIf('ten_three_star', threeStarCount >= 10);
  addIf('first_no_hint', noHintClears >= 1);
  addIf('five_no_hint', noHintClears >= 5);
  addIf('first_hidden', discoveredHidden.isNotEmpty);
  addIf('five_hidden', discoveredHidden.length >= 5);
  addIf('first_route', routePostcards >= 1);
  addIf('both_routes', bothRoutes);
  addIf('first_world', worldStamps >= 1);
  addIf('three_worlds', worldStamps >= 3);
  addIf('all_worlds', worldStamps >= 8);
  addIf('first_ending', endingPairs.isNotEmpty);
  addIf('three_endings', endingPairs.length >= 3);
  addIf('streak_3', streakDays >= 3);
  addIf('streak_7', streakDays >= 7);
  addIf('xp_500', xp >= 500);
  addIf('stars_100', totalStars >= 100);
  return earned;
}
