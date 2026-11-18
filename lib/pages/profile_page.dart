/// F0: profile tab (我的): traveller level, XP, stars, settings entry,
/// and an F0 debug reset. History adds the play-history section below
/// the stats card: the 20 most recent attempts, tap one for details.
library;

import 'package:material_ui/material_ui.dart';

import '../history.dart';
import '../levels.dart';
import '../progress.dart';
import '../settings.dart';
import '../theme.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.graph,
    required this.progress,
    required this.settings,
    required this.history,
  });

  final LevelGraph graph;
  final ProgressStore progress;
  final SettingsStore settings;
  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    final totalStars = progress.totalStars;
    final maxStars = graph.totalLevels * 3;
    final nextLevelAt = progress.travellerLevel * LevelRewards.xpPerLevel;
    final (mainDone, mainTotal) = progress.mainlineProgress(graph);
    final (exploreDone, exploreTotal) = progress.explorationProgress(graph);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '旅行者 Lv.${progress.travellerLevel}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('XP ${progress.xp} / $nextLevelAt'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.xp / nextLevelAt,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: SpeakMindColors.actionGreen,
                  ),
                  const SizedBox(height: 8),
                  Text('星星 $totalStars / $maxStars'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: maxStars == 0 ? 0 : totalStars / maxStars,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: SpeakMindColors.amber,
                  ),
                  const SizedBox(height: 12),
                  Text('主线完成度 $mainDone / $mainTotal'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: mainTotal == 0 ? 0 : mainDone / mainTotal,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: SpeakMindColors.actionGreen,
                  ),
                  const SizedBox(height: 8),
                  Text('探索完成度 $exploreDone / $exploreTotal（支线 + 隐藏 + 结局）'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: exploreTotal == 0
                        ? 0
                        : exploreDone / exploreTotal,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: SpeakMindColors.amber,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '连续学习 ${progress.streakDays} 天 · 邮票 ${progress.postcards(graph).length} 张 · 贴纸 ${progress.earnedStickerIds.length} / 18',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HistorySection(graph: graph, history: history),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            subtitle: const Text('服务器地址、语言'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(settings: settings),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('重置进度（F0 调试）'),
            subtitle: const Text('回到只解锁 1-1 的状态'),
            onTap: () async {
              await progress.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('进度已重置')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// The play-history section: the 20 most recent attempts, newest first.
/// Rebuilds when the store changes (a level just finished, a sync landed).
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.graph, required this.history});

  final LevelGraph graph;
  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final recent = history.recent(20);
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '游玩记录',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (recent.isEmpty)
                  const Text(
                    '还没有游玩记录，打一关就会出现在这里。',
                    style: TextStyle(color: SpeakMindColors.fog),
                  )
                else
                  for (final record in recent)
                    _HistoryRow(
                      record: record,
                      title: graph.levelById(record.levelId)?.titleZh ??
                          record.levelId,
                      onTap: () => _showDetail(context, record),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, HistoryRecord record) {
    final node = graph.levelById(record.levelId);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record.levelId} ${node?.titleZh ?? ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('状态', record.completed ? '已通关' : '未完成（中途退出）'),
              _DetailRow('星星', '★${record.stars}'),
              _DetailRow('XP', '+${record.xpEarned}'),
              if (record.pronAvg != null)
                _DetailRow('发音平均', '${record.pronAvg!.toStringAsFixed(0)} 分'),
              if (record.challengeScore != null)
                _DetailRow('挑战句发音', '${record.challengeScore} 分'),
              _DetailRow('对话轮数', '${record.rounds} 轮'),
              _DetailRow('提示用了', '${record.hintsUsed} 次'),
              if (record.weakestSentence != null)
                _DetailRow('最弱的一句', record.weakestSentence!),
              _DetailRow('开始', _fullDate(record.startedAt)),
              _DetailRow('结束', _fullDate(record.finishedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.title,
    required this.onTap,
  });

  final HistoryRecord record;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      _shortDate(record.finishedAt),
      if (!record.completed) '未完成',
      '★${record.stars}',
      if (record.pronAvg != null) '发音 ${record.pronAvg!.toStringAsFixed(0)} 分',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${record.levelId} $title'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(color: SpeakMindColors.fog),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// MM-dd HH:mm, local time.
String _shortDate(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// yyyy-MM-dd HH:mm, local time.
String _fullDate(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} '
      '${_two(l.hour)}:${_two(l.minute)}';
}
