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
            title: '世界邮票',
            count: '${[for (var w = 1; w <= 8; w++) w].where((w) => hasWorldStamp(progress.starsById, w)).length} / 8',
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: graph.worlds.length,
            itemBuilder: (context, index) {
              final world = graph.worlds[index];
              final stars = progress.worldStars(world.id, graph);
              final completed = hasWorldStamp(progress.starsById, world.id);
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        completed ? Icons.mark_as_unread : Icons.drafts,
                        size: 40,
                        color: completed
                            ? SpeakMindColors.amber
                            : SpeakMindColors.fog,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'W${world.id} ${world.nameZh}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        completed
                            ? '★ $stars/30 · 已获得'
                            : '★ $stars/30 · 通关 Boss 关获得',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SpeakMindColors.fog,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: '场景明信片',
            count: '${earnedCards.length} / 30',
          ),
          const SizedBox(height: 4),
          const Text(
            '点一张已获得的明信片，可以回听背面的 3 句地道说法。',
            style: TextStyle(color: SpeakMindColors.fog),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: _allPostcardIds(graph).length,
            itemBuilder: (context, index) {
              final id = _allPostcardIds(graph)[index];
              final earned = earnedCards.contains(id);
              final details = postcardDetails(id, graph);
              final isHidden = id.startsWith('hidden:');
              return InkWell(
                onTap: earned && details != null
                    ? () => _showPostcard(context, details)
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: earned
                        ? BorderSide.none
                        : const BorderSide(
                            color: SpeakMindColors.fog,
                            style: BorderStyle.solid,
                            width: 1,
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          earned ? Icons.mail : Icons.mail_outline,
                          size: 32,
                          color: earned
                              ? SpeakMindColors.actionGreen
                              : SpeakMindColors.fog,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          earned
                              ? (details?.titleZh ?? id)
                              : isHidden
                                  ? '隐藏明信片'
                                  : '未获得的明信片',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          earned
                              ? '点开回听 3 句话'
                              : isHidden
                                  ? '完成一个隐藏关获得'
                                  : '完成一条支线获得',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: SpeakMindColors.fog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
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
                          fontSize: 11,
                          color: SpeakMindColors.fog,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// All postcard ids in a stable order: routes first (by world, then
  /// route), then hidden levels (by world).
  List<String> _allPostcardIds(LevelGraph graph) {
    final ids = <String>[];
    for (final level in graph.levels) {
      if (level.kind != LevelKind.main || !level.isFork) continue;
      for (final route in level.branches ?? const <LevelBranch>[]) {
        ids.add('route:${level.world}:${route.route}');
      }
    }
    for (final hidden in graph.levels.where((l) => l.kind == LevelKind.hidden)) {
      ids.add('hidden:${hidden.id}');
    }
    return ids;
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(count, style: const TextStyle(color: SpeakMindColors.fog)),
      ],
    );
  }
}
