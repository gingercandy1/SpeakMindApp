/// F2 tests: Chispa's face renders in every mood, and the star-to-mood
/// mapping picks the right expression for the results screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speakmind/chispa.dart';

void main() {
  group('moodForStars', () {
    test('3 stars cheer, 2 proud, 1 encourage, 0 thinking', () {
      expect(moodForStars(3), ChispaMood.cheer);
      expect(moodForStars(2), ChispaMood.proud);
      expect(moodForStars(1), ChispaMood.encourage);
      expect(moodForStars(0), ChispaMood.thinking);
    });
  });

  group('ChispaFace', () {
    testWidgets('renders every mood without error', (tester) async {
      for (final mood in ChispaMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: ChispaFace(mood: mood)),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(ChispaFace), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    test('mascot name is the single constant', () {
      expect(mascotName, 'Chispa');
    });
  });
}
