/// F0: profile tab (我的): traveller level, XP, stars, settings entry,
/// and an F0 debug reset.
library;

import 'package:material_ui/material_ui.dart';

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
  });

  final LevelGraph graph;
  final ProgressStore progress;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final totalStars = progress.totalStars;
    final maxStars = graph.totalLevels * 3;
    final nextLevelAt = progress.travellerLevel * LevelRewards.xpPerLevel;
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SpeakMindColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('XP ${progress.xp} / $nextLevelAt'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.xp / nextLevelAt,
                    backgroundColor: SpeakMindColors.cream,
                    color: SpeakMindColors.actionGreen,
                  ),
                  const SizedBox(height: 8),
                  Text('星星 $totalStars / $maxStars'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: maxStars == 0 ? 0 : totalStars / maxStars,
                    backgroundColor: SpeakMindColors.cream,
                    color: SpeakMindColors.amber,
                  ),
                ],
              ),
            ),
          ),
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
