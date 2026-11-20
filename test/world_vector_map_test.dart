import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/levels.dart';
import 'package:speakmind/progress.dart';
import 'package:speakmind/theme.dart';
import 'package:speakmind/widgets/world_vector_map.dart';

void main() {
  testWidgets('every world scene paints without error', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = await ProgressStore.load();
    final graph = (await tester.runAsync(() async {
      final raw = await rootBundle.loadString('assets/levels_es.json');
      return LevelGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }))!;

    for (final world in graph.worlds) {
      final nodes = graph.mainlineOfWorld(world.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: speakMindTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorldVectorMap(
                world: world,
                nodes: nodes,
                graph: graph,
                progress: progress,
                nodeBuilder: (node, i, isCurrent) =>
                    SizedBox(width: 56, height: 56, child: Text('${i + 1}')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // The landmark band and the route are drawn; each node is placed.
      expect(find.text('1'), findsOneWidget);
    }
  });
}
