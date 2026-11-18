/// F2: branch route choice page (支线选择页, levels dev doc §8).
///
/// Opened from a fork card on the map (or from the results screen after
/// finishing a level-5 fork). The two routes share the same grammar point
/// with different scenes and vocabulary, so either one teaches the lesson;
/// the first pick counts toward the journey, the other route stays as
/// "未走的路" until its world is complete, then it opens for a revisit.
library;

import 'package:material_ui/material_ui.dart';

import '../chispa.dart';
import '../levels.dart';
import '../progress.dart';
import '../settings.dart';
import '../theme.dart';
import 'level_page.dart';

class BranchPage extends StatelessWidget {
  const BranchPage({
    super.key,
    required this.fork,
    required this.graph,
    required this.progress,
    required this.settings,
  });

  /// The level-5 fork node whose routes are on offer.
  final LevelNode fork;

  final LevelGraph graph;
  final ProgressStore progress;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final chosen = progress.branchChoice(fork.id);
    final worldDone = progress.isWorldComplete(fork.world, graph);
    final routes = fork.branches ?? const <LevelBranch>[];
    return Scaffold(
      appBar: AppBar(title: Text('${fork.id} 岔路口')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const ChispaFace(mood: ChispaMood.greeting, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '两条路，同一个语法点，场景不同。先选一条走，'
                  '另一条等这个世界通关后可以回来补打。',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final route in routes)
            _RouteCard(
              route: route,
              graph: graph,
              progress: progress,
              settings: settings,
              state: chosen == route.route
                  ? _RouteState.chosen
                  : worldDone || chosen == null
                      ? _RouteState.available
                      : _RouteState.locked,
              onPick: chosen == null ? () => _pick(context, route) : null,
            ),
          const SizedBox(height: 16),
          Text(
            '选定后另一条路不会消失：世界通关后回到这里，它会变成虚线小路等你。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, LevelBranch route) async {
    final ok = await progress.chooseBranch(fork.id, route.route, graph);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这条线已经选过了')),
      );
      return;
    }
    final first = graph.levelById(route.levels.first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已选 ${route.labelZh}，第一关已解锁')),
    );
    if (first == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LevelPage(
          node: first,
          graph: graph,
          progress: progress,
          settings: settings,
        ),
      ),
    );
  }
}

enum _RouteState { chosen, available, locked }

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.graph,
    required this.progress,
    required this.settings,
    required this.state,
    required this.onPick,
  });

  final LevelBranch route;
  final LevelGraph graph;
  final ProgressStore progress;
  final SettingsStore settings;
  final _RouteState state;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = route.levels.isEmpty
        ? null
        : graph.levelById(route.levels.first);
    final levels = [
      for (final id in route.levels) graph.levelById(id),
    ];
    final doneCount =
        levels.where((l) => l != null && progress.isCompleted(l.id)).length;
    return Card(
      color: state == _RouteState.chosen ? scheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: state == _RouteState.chosen
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${route.label} · ${route.labelZh}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (state == _RouteState.chosen)
                  Chip(
                    label: Text('已选 · $doneCount/3 关'),
                    backgroundColor: scheme.primary,
                    labelStyle: TextStyle(color: scheme.onPrimary),
                  )
                else if (state == _RouteState.locked)
                  const Chip(label: Text('世界通关后回访')),
              ],
            ),
            if (first?.scene != null) ...[
              const SizedBox(height: 6),
              Text(
                first!.scene!,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            for (final level in levels)
              if (level != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        progress.isCompleted(level.id)
                            ? Icons.check_circle
                            : progress.isUnlocked(level.id)
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                        size: 18,
                        color: progress.isCompleted(level.id)
                            ? SpeakMindColors.actionGreen
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${level.id} ${level.title} · ${level.titleZh}',
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            if (state == _RouteState.available)
              ElevatedButton(
                onPressed: onPick,
                child: Text('选这条线：${route.labelZh}'),
              )
            else if (state == _RouteState.chosen && doneCount < 3)
              OutlinedButton(
                onPressed: () => _continueRoute(context, levels),
                child: const Text('继续这条线'),
              ),
          ],
        ),
      ),
    );
  }

  void _continueRoute(BuildContext context, List<LevelNode?> levels) {
    final next = levels.firstWhere(
      (l) => l != null && !progress.isCompleted(l.id),
      orElse: () => levels.last,
    );
    if (next == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LevelPage(
          node: next,
          graph: graph,
          progress: progress,
          settings: settings,
        ),
      ),
    );
  }
}
