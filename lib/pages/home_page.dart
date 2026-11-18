/// F0: home shell. Loads the level graph once, then shows the four tabs
/// from the final planning doc: 地图 (home), 邮票册, 练习场, 我的.
/// PracticePage (with its ChatPage entry) stays as-is under 练习场.
library;

import 'package:material_ui/material_ui.dart';

import '../levels.dart';
import '../progress.dart';
import '../settings.dart';
import 'map_page.dart';
import 'practice_page.dart';
import 'profile_page.dart';
import 'stamps_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.settings,
    required this.progress,
    this.graph,
  });

  final SettingsStore settings;
  final ProgressStore progress;

  /// Preloaded graph. When null (the app's normal path) the graph is
  /// loaded from assets/levels_es.json. Widget tests pass a graph
  /// loaded with rootBundle so they don't depend on the async load
  /// completing inside a pumped frame.
  final LevelGraph? graph;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<LevelGraph> _graph;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _graph = widget.graph != null
        ? Future<LevelGraph>.value(widget.graph!)
        : LevelGraph.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LevelGraph>(
      future: _graph,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('SpeakMind')),
            body: Center(
              child: Text('关卡配置加载失败：${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final graph = snapshot.data!;
        final pages = <Widget>[
          MapPage(
            graph: graph,
            progress: widget.progress,
            settings: widget.settings,
          ),
          StampsPage(
            graph: graph,
            progress: widget.progress,
            settings: widget.settings,
          ),
          PracticePage(settings: widget.settings),
          ProfilePage(
            graph: graph,
            progress: widget.progress,
            settings: widget.settings,
          ),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (index) => setState(() => _tab = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.map), label: '地图'),
              BottomNavigationBarItem(
                icon: Icon(Icons.collections_bookmark),
                label: '邮票册',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.mic), label: '练习场'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        );
      },
    );
  }
}
