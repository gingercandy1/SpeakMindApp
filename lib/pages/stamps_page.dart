/// F0: stamp book placeholder (邮票册).
///
/// 8 world slots, one per world, shown as 邮票 (stamp) frames. F2 issues
/// real stamps when a world completes; here they are locked/empty.
library;

import 'package:material_ui/material_ui.dart';

import '../levels.dart';
import '../progress.dart';
import '../theme.dart';

class StampsPage extends StatelessWidget {
  const StampsPage({super.key, required this.graph, required this.progress});

  final LevelGraph graph;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邮票册')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '每完成一个世界，就能拿到一张邮票。邮票只记录旅程，不挡主线。',
            style: TextStyle(color: SpeakMindColors.fog),
          ),
          const SizedBox(height: 16),
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
              final completed = stars >= 30;
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
                        completed ? '★ $stars/30 · 已获得' : '★ $stars/30 · F2 发行',
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
        ],
      ),
    );
  }
}
