/// F0: world map screen (the home screen).
///
/// Renders the level graph from `assets/levels_es.json`: 8 worlds, mainline
/// nodes along a zigzag path, branch forks after each world's level 5, and
/// discovered hidden nodes as gold stars. Undiscovered worlds show fog
/// (name visible, nodes hidden); undiscovered hidden nodes show nothing.
/// Lock/unlock state comes from [ProgressStore]. Tapping an unlocked node
/// opens the level page; tapping a locked node explains why.
library;

import 'package:material_ui/material_ui.dart';

import '../levels.dart';
import '../progress.dart';
import '../settings.dart';
import '../theme.dart';
import 'level_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.graph,
    required this.progress,
    required this.settings,
  });

  final LevelGraph graph;
  final ProgressStore progress;

  /// Passed through to the level page (server URL + voices).
  final SettingsStore settings;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  void _openLevel(LevelNode node) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LevelPage(
          node: node,
          graph: widget.graph,
          progress: widget.progress,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _showLocked(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    final progress = widget.progress;
    final current = progress.currentLevel(graph);
    return Scaffold(
      appBar: AppBar(
        title: const Text('世界地图'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'F0 调试',
            onSelected: (value) async {
              if (value == 'hidden') {
                await progress.discoverHidden('1H-1');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已发现隐藏关 1H-1 秘密小酒窖')),
                  );
                }
              } else if (value == 'reset') {
                await progress.reset();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'hidden',
                child: Text('模拟发现隐藏关 1H-1（F0 调试）'),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Text('重置进度（F0 调试）'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _StatsRow(progress: progress, graph: graph),
          const SizedBox(height: 12),
          _ContinueCard(current: current, onTap: _openLevel),
          const SizedBox(height: 8),
          for (final world in graph.worlds) ...[
            const SizedBox(height: 16),
            _WorldSection(
              world: world,
              graph: graph,
              progress: progress,
              onOpenLevel: _openLevel,
              onLocked: _showLocked,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.progress, required this.graph});

  final ProgressStore progress;
  final LevelGraph graph;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Stat(label: '等级', value: 'Lv.${progress.travellerLevel}'),
        _Stat(label: 'XP', value: '${progress.xp}'),
        _Stat(
          label: '星星',
          value: '${progress.totalStars} / ${graph.totalLevels * 3}',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: SpeakMindColors.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: SpeakMindColors.fog),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.current, required this.onTap});

  final LevelNode? current;
  final void Function(LevelNode) onTap;

  @override
  Widget build(BuildContext context) {
    final node = current;
    return Card(
      color: SpeakMindColors.deepTeal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: node == null
            ? const Text(
                '全部关卡已完成！',
                style: TextStyle(color: Colors.white, fontSize: 17),
              )
            : Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: SpeakMindColors.amber,
                    child: Text(
                      'B',
                      style: TextStyle(
                        color: SpeakMindColors.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '继续：${node.id} ${node.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${node.titleZh} · ${node.cefr}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => onTap(node),
                    child: const Text('继续'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WorldSection extends StatelessWidget {
  const _WorldSection({
    required this.world,
    required this.graph,
    required this.progress,
    required this.onOpenLevel,
    required this.onLocked,
  });

  final WorldInfo world;
  final LevelGraph graph;
  final ProgressStore progress;
  final void Function(LevelNode) onOpenLevel;
  final void Function(String) onLocked;

  @override
  Widget build(BuildContext context) {
    final mainline = graph.mainlineOfWorld(world.id);
    final unlocked = progress.isWorldUnlocked(world.id, graph);
    final stars = progress.worldStars(world.id, graph);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorldHeader(world: world, stars: stars, unlocked: unlocked),
        const SizedBox(height: 8),
        if (!unlocked)
          _FogCard(world: world)
        else ...[
          for (var i = 0; i < mainline.length; i++) ...[
            _MainlineNode(
              node: mainline[i],
              index: i,
              progress: progress,
              graph: graph,
              onOpenLevel: onOpenLevel,
              onLocked: onLocked,
            ),
            if (mainline[i].isFork)
              _ForkCard(
                node: mainline[i],
                graph: graph,
                progress: progress,
                onOpenLevel: onOpenLevel,
                onLocked: onLocked,
              ),
          ],
          for (final hidden in graph.hiddenOfWorld(world.id))
            if (progress.isVisible(hidden, graph))
              _HiddenNode(
                node: hidden,
                progress: progress,
                onOpenLevel: onOpenLevel,
              ),
        ],
      ],
    );
  }
}

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({
    required this.world,
    required this.stars,
    required this.unlocked,
  });

  final WorldInfo world;
  final int stars;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: unlocked
              ? SpeakMindColors.deepTeal
              : SpeakMindColors.fog,
          child: Text(
            'W${world.id}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${world.name} · ${world.nameZh}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: SpeakMindColors.ink,
                ),
              ),
              Text(
                '${world.theme} · ${world.grammar}',
                style: const TextStyle(
                  fontSize: 12,
                  color: SpeakMindColors.fog,
                ),
              ),
            ],
          ),
        ),
        Chip(
          label: Text(world.cefr),
          backgroundColor: SpeakMindColors.cream,
        ),
        const SizedBox(width: 6),
        Text(
          '★ $stars/30',
          style: const TextStyle(color: SpeakMindColors.amber),
        ),
      ],
    );
  }
}

class _FogCard extends StatelessWidget {
  const _FogCard({required this.world});

  final WorldInfo world;

  @override
  Widget build(BuildContext context) {
    final req = world.unlockRequiresWorld;
    final need = world.unlockMinMainlineStars ?? 0;
    return Card(
      color: const Color(0xFFEDE7D8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.cloud,
              color: SpeakMindColors.fog,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                req == null
                    ? '未到达的世界'
                    : '云雾未散：W$req 主线拿到 $need 星后解锁',
                style: const TextStyle(color: SpeakMindColors.fog),
              ),
            ),
            const Icon(Icons.lock_outline, color: SpeakMindColors.fog),
          ],
        ),
      ),
    );
  }
}

class _MainlineNode extends StatelessWidget {
  const _MainlineNode({
    required this.node,
    required this.index,
    required this.progress,
    required this.graph,
    required this.onOpenLevel,
    required this.onLocked,
  });

  final LevelNode node;
  final int index;
  final ProgressStore progress;
  final LevelGraph graph;
  final void Function(LevelNode) onOpenLevel;
  final void Function(String) onLocked;

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.isUnlocked(node.id);
    final stars = progress.stars(node.id);
    final current = progress.currentLevel(graph)?.id == node.id;
    // Zigzag path: alternate left / right down the world.
    final alignment = index.isEven
        ? Alignment.centerLeft
        : Alignment.centerRight;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: _LevelNodeButton(
          node: node,
          label: '${index + 1}',
          unlocked: unlocked,
          stars: stars,
          isCurrent: current,
          isHidden: false,
          onOpen: onOpenLevel,
          onLocked: () => onLocked('先完成上一关才能解锁 ${node.id}'),
        ),
      ),
    );
  }
}

class _HiddenNode extends StatelessWidget {
  const _HiddenNode({
    required this.node,
    required this.progress,
    required this.onOpenLevel,
  });

  final LevelNode node;
  final ProgressStore progress;
  final void Function(LevelNode) onOpenLevel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _LevelNodeButton(
          node: node,
          label: '✦',
          unlocked: true,
          stars: progress.stars(node.id),
          isCurrent: false,
          isHidden: true,
          onOpen: onOpenLevel,
          onLocked: () {},
        ),
      ),
    );
  }
}

/// One tappable level node: circle + stars + title.
class _LevelNodeButton extends StatelessWidget {
  const _LevelNodeButton({
    required this.node,
    required this.label,
    required this.unlocked,
    required this.stars,
    required this.isCurrent,
    required this.isHidden,
    required this.onOpen,
    required this.onLocked,
  });

  final LevelNode node;
  final String label;
  final bool unlocked;
  final int stars;
  final bool isCurrent;
  final bool isHidden;
  final void Function(LevelNode) onOpen;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    if (!unlocked) {
      fill = SpeakMindColors.cream;
    } else if (stars >= 3) {
      fill = SpeakMindColors.starGold;
    } else if (stars > 0) {
      fill = SpeakMindColors.actionGreen;
    } else {
      fill = Colors.white;
    }
    return InkWell(
      onTap: () => unlocked ? onOpen(node) : onLocked(),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: isCurrent
                    ? SpeakMindColors.amber
                    : (unlocked
                        ? SpeakMindColors.deepTeal
                        : SpeakMindColors.fog),
                width: isCurrent ? 3 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: unlocked ? SpeakMindColors.ink : SpeakMindColors.fog,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 3; i++)
                Icon(
                  i <= stars ? Icons.star : Icons.star_border,
                  size: 14,
                  color: i <= stars
                      ? SpeakMindColors.amber
                      : SpeakMindColors.fog,
                ),
            ],
          ),
          SizedBox(
            width: 110,
            child: Text(
              isHidden ? '✦ ${node.titleZh}' : node.titleZh,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: unlocked
                    ? SpeakMindColors.ink
                    : SpeakMindColors.fog,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fork after a world's level 5: two routes, each with 3 small nodes.
class _ForkCard extends StatelessWidget {
  const _ForkCard({
    required this.node,
    required this.graph,
    required this.progress,
    required this.onOpenLevel,
    required this.onLocked,
  });

  final LevelNode node;
  final LevelGraph graph;
  final ProgressStore progress;
  final void Function(LevelNode) onOpenLevel;
  final void Function(String) onLocked;

  @override
  Widget build(BuildContext context) {
    final routes = node.branches ?? const <LevelBranch>[];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.call_split,
                  color: SpeakMindColors.actionGreen,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '岔路口：选一条线先走',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '汇合回 ${routes.isNotEmpty ? routes.first.rejoin : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SpeakMindColors.fog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final route in routes)
                  Expanded(child: _RouteColumn(
                    route: route,
                    graph: graph,
                    progress: progress,
                    onOpenLevel: onOpenLevel,
                    onLocked: onLocked,
                  )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteColumn extends StatelessWidget {
  const _RouteColumn({
    required this.route,
    required this.graph,
    required this.progress,
    required this.onOpenLevel,
    required this.onLocked,
  });

  final LevelBranch route;
  final LevelGraph graph;
  final ProgressStore progress;
  final void Function(LevelNode) onOpenLevel;
  final void Function(String) onLocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${route.label}\n${route.labelZh}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        for (final id in route.levels)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _BranchNode(
              node: graph.levelById(id),
              progress: progress,
              onOpenLevel: onOpenLevel,
              onLocked: onLocked,
            ),
          ),
      ],
    );
  }
}

class _BranchNode extends StatelessWidget {
  const _BranchNode({
    required this.node,
    required this.progress,
    required this.onOpenLevel,
    required this.onLocked,
  });

  final LevelNode? node;
  final ProgressStore progress;
  final void Function(LevelNode) onOpenLevel;
  final void Function(String) onLocked;

  @override
  Widget build(BuildContext context) {
    final n = node;
    if (n == null) return const SizedBox.shrink();
    final unlocked = progress.isUnlocked(n.id);
    final stars = progress.stars(n.id);
    return InkWell(
      onTap: () => unlocked
          ? onOpenLevel(n)
          : onLocked('分支关要先打通 ${n.id} 所在的岔路口'),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !unlocked
                  ? SpeakMindColors.cream
                  : (stars >= 3
                      ? SpeakMindColors.starGold
                      : SpeakMindColors.actionGreen),
              border: Border.all(
                color: unlocked
                    ? SpeakMindColors.deepTeal
                    : SpeakMindColors.fog,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              n.id.split('-').last,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: unlocked ? SpeakMindColors.ink : SpeakMindColors.fog,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 3; i++)
                Icon(
                  i <= stars ? Icons.star : Icons.star_border,
                  size: 11,
                  color: i <= stars
                      ? SpeakMindColors.amber
                      : SpeakMindColors.fog,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
