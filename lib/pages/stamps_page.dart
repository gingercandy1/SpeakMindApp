/// F2: stamp book (邮票册) — three sections, all computed from progress.
///
/// * 世界邮票 (8): one per world, issued by finishing its Boss level.
/// * 场景明信片 (30): one per finished branch route (14) and hidden level
///   (16). Tapping an earned postcard shows its three authentic phrases
///   on the back, each playable with TTS (明信片回听, F4).
/// * Chispa 贴纸 (18): achievements. Unearned ones show only a dashed
///   silhouette and their condition — hidden postcards never reveal
///   their name before they are earned.
library;

import 'package:material_ui/material_ui.dart';

import '../levels.dart';
import '../progress.dart';
import '../settings.dart';
import '../speech.dart';
import '../stamps.dart';
import '../theme.dart';
import '../widgets/dashed_border.dart';
import '../widgets/stamp_icon.dart';

class StampsPage extends StatefulWidget {
  const StampsPage({
    super.key,
    required this.graph,
    required this.progress,
    required this.settings,
  });

  final LevelGraph graph;
  final ProgressStore progress;
  final SettingsStore settings;

  @override
  State<StampsPage> createState() => _StampsPageState();
}

class _StampsPageState extends State<StampsPage> {
  Speaker? _speaker;

  Speaker get _tts => _speaker ??= Speaker(widget.settings);

  @override
  void dispose() {
    _speaker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final graph = widget.graph;
    final earnedCards = progress.postcards(graph);
    final earnedStickers = progress.earnedStickerIds;
    return Scaffold(
      appBar: AppBar(title: const Text('邮票册')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '邮票只记录旅程，不挡主线。世界邮票来自 Boss 关，明信片来自支线与隐藏关，贴纸来自成就。',
            style: TextStyle(color: SpeakMindColors.fog),
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            title: '旅行手帐',
            count:
                '${[for (var w = 1; w <= 8; w++) w].where((w) => hasWorldStamp(progress.starsById, w)).length} / 8 邮票 · ${earnedCards.length} / 30 明信片',
          ),
          const SizedBox(height: 4),
          const Text(
            '左页是世界邮票，右页是这个世界的明信片。点一张已获得的明信片，可以回听背面的 3 句地道说法。',
            style: TextStyle(color: SpeakMindColors.fog),
          ),
          const SizedBox(height: 8),
          for (final world in graph.worlds)
            _JournalSpread(
              world: world,
              graph: graph,
              stars: progress.worldStars(world.id, graph),
              hasStamp: hasWorldStamp(progress.starsById, world.id),
              postcardIds: _postcardsByWorld(graph)[world.id] ?? const [],
              earnedCards: earnedCards,
              onPostcard: (details) => _showPostcard(context, details),
            ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Chispa 贴纸',
            count: '${earnedStickers.length} / ${stickerCatalog.length}',
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: stickerCatalog.length,
            itemBuilder: (context, index) {
              final sticker = stickerCatalog[index];
              final earned = earnedStickers.contains(sticker.id);
              final tile = Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      earned ? Icons.emoji_events : Icons.help_outline,
                      size: 30,
                      color: earned
                          ? SpeakMindColors.amber
                          : SpeakMindColors.fog,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      earned ? sticker.name : '？',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      sticker.how,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SpeakMindColors.fog,
                      ),
                    ),
                  ],
                ),
              );
              // Unearned stickers show only a dashed silhouette (doc p.12).
              if (!earned) return DashedBorder(child: tile);
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: tile,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Postcard ids grouped by world, in the same stable order as
  /// [_allPostcardIds]: routes first, then hidden levels.
  Map<int, List<String>> _postcardsByWorld(LevelGraph graph) {
    final byWorld = <int, List<String>>{};
    for (final level in graph.levels) {
      if (level.kind != LevelKind.main || !level.isFork) continue;
      for (final route in level.branches ?? const <LevelBranch>[]) {
        (byWorld[level.world] ??= []).add('route:${level.world}:${route.route}');
      }
    }
    for (final hidden in graph.levels.where((l) => l.kind == LevelKind.hidden)) {
      final world = int.tryParse(hidden.id.substring(0, 1)) ?? 1;
      (byWorld[world] ??= []).add('hidden:${hidden.id}');
    }
    return byWorld;
  }

  Future<void> _showPostcard(BuildContext context, Postcard card) async {
    final spanish = languages.firstWhere((l) => l.code == 'es');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${card.title}\n${card.titleZh}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('背面的 3 句地道说法，点 🔊 回听：'),
            const SizedBox(height: 8),
            for (final phrase in card.phrases)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(phrase, style: const TextStyle(fontSize: 16)),
                    ),
                    IconButton(
                      tooltip: '听这句',
                      onPressed: () => _tts.speak(phrase, spanish),
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('收起来'),
          ),
        ],
      ),
    );
  }
}

/// One world's journal spread (doc p.12): left page the world stamp,
/// right page that world's postcards, with a book spine between them.
/// Unobtained slots show only a dashed silhouette; hidden postcards never
/// reveal their name before they are earned.
class _JournalSpread extends StatelessWidget {
  const _JournalSpread({
    required this.world,
    required this.graph,
    required this.stars,
    required this.hasStamp,
    required this.postcardIds,
    required this.earnedCards,
    required this.onPostcard,
  });

  final WorldInfo world;
  final LevelGraph graph;
  final int stars;
  final bool hasStamp;
  final List<String> postcardIds;
  final Set<String> earnedCards;
  final void Function(Postcard) onPostcard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 116, child: _stamp()),
                // Book spine.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 1,
                    color: SpeakMindColors.fog.withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < postcardIds.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _postcard(postcardIds[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Left page: the world stamp. Earned stamps sit on a perforated
  /// (dashed-inner-border) card; unobtained ones are a dashed silhouette.
  Widget _stamp() {
    final inner = Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StampIcon(
            size: 36,
            color: hasStamp
                ? SpeakMindColors.amber
                : SpeakMindColors.fog,
          ),
          const SizedBox(height: 6),
          Text(
            'W${world.id} ${world.nameZh}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            hasStamp ? '★ $stars/30 · 已获得' : '★ $stars/30 · 通关 Boss 关获得',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: SpeakMindColors.fog,
            ),
          ),
        ],
      ),
    );
    if (!hasStamp) return DashedBorder(child: inner);
    return DashedBorder(
      color: SpeakMindColors.amber,
      child: Container(
        color: SpeakMindColors.amber.withValues(alpha: 0.12),
        child: inner,
      ),
    );
  }

  /// Right page: one postcard row (icon + title + condition).
  Widget _postcard(String id) {
    final earned = earnedCards.contains(id);
    final details = postcardDetails(id, graph);
    final isHidden = id.startsWith('hidden:');
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          PostcardIcon(
            size: 30,
            color: earned
                ? SpeakMindColors.actionGreen
                : SpeakMindColors.fog,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earned
                      ? (details?.titleZh ?? id)
                      : isHidden
                          ? '隐藏明信片'
                          : '未获得的明信片',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  earned
                      ? '点开回听 3 句话'
                      : isHidden
                          ? '完成一个隐藏关获得'
                          : '完成一条支线获得',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SpeakMindColors.fog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!earned) return DashedBorder(child: inner);
    return InkWell(
      onTap: details != null ? () => onPostcard(details) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: SpeakMindColors.actionGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: SpeakMindColors.actionGreen.withValues(alpha: 0.4),
          ),
        ),
        child: inner,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(width: 8),
        Text(count, style: const TextStyle(color: SpeakMindColors.fog)),
      ],
    );
  }
}
