/// F0: placeholder level screen.
///
/// Shows the level's identity from the graph and the six-step loop as a
/// disabled outline. No teaching content yet: words, sentences, NPC prompt
/// and task are all TODO for F1. The "模拟通关" button is an F0 test hook so
/// the unlock logic on the map can be exercised end to end; F1 replaces it
/// with real gameplay and scoring.
library;

import 'package:material_ui/material_ui.dart';

import '../levels.dart';
import '../progress.dart';
import '../theme.dart';

/// The six steps of every level (levels dev doc §6). Shown as an outline
/// only in F0; F1 fills each step with real content.
const levelSteps = <String>[
  '1 剧情引入',
  '2 学词句',
  '3 跟读闯关',
  '4 情境对话',
  '5 挑战题',
  '6 结算',
];

class LevelPage extends StatelessWidget {
  const LevelPage({
    super.key,
    required this.node,
    required this.graph,
    required this.progress,
  });

  final LevelNode node;
  final LevelGraph graph;
  final ProgressStore progress;

  String get _kindLabel => switch (node.kind) {
        LevelKind.main => '主线',
        LevelKind.branch => '分支',
        LevelKind.hidden => '隐藏',
      };

  @override
  Widget build(BuildContext context) {
    final world = graph.worldById(node.world);
    return Scaffold(
      appBar: AppBar(
        title: Text('${node.id} ${node.title}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Chip(label: Text(_kindLabel)),
              const SizedBox(width: 8),
              Chip(label: Text('W${node.world} ${world.nameZh}')),
              const SizedBox(width: 8),
              Chip(label: Text(node.cefr)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            node.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SpeakMindColors.ink,
            ),
          ),
          Text(
            node.titleZh,
            style: const TextStyle(
              fontSize: 17,
              color: SpeakMindColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发音过关线：GOP ${node.passGop} 分 · 已得星星：${'★' * progress.stars(node.id)}${'☆' * (3 - progress.stars(node.id))}',
            style: const TextStyle(color: SpeakMindColors.fog),
          ),
          if (node.hiddenTrigger != null) ...[
            const SizedBox(height: 8),
            Text(
              '发现条件：${node.hiddenTrigger!.note ?? node.hiddenTrigger!.type}',
              style: const TextStyle(color: SpeakMindColors.amber),
            ),
          ],
          const SizedBox(height: 16),
          const Card(
            color: Color(0xFFFFF3D6),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '本关内容正在 F1 制作中：单词、句型、NPC 对话与挑战任务都还是空的，'
                '这里先展示关卡结构。',
                style: TextStyle(color: SpeakMindColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '单关六步（F1 填充）',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final step in levelSteps)
            ListTile(
              leading: const Icon(
                Icons.circle_outlined,
                color: SpeakMindColors.fog,
              ),
              title: Text(step),
              enabled: false,
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await progress.completeLevel(node, graph, stars: 3);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('模拟通关 ★★★（F0 测试用）'),
          ),
          const SizedBox(height: 8),
          const Text(
            '点上面这个按钮会记 3 星、加 XP，并按图结构解锁下一关（主线下一关、'
            '岔路口的两条支线入口）。F1 会换成真正的打关流程。',
            style: TextStyle(fontSize: 12, color: SpeakMindColors.fog),
          ),
        ],
      ),
    );
  }
}
