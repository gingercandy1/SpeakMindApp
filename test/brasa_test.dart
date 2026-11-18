/// F2 tests: Brasa's face renders in every mood, and the star-to-mood
/// mapping picks the right expression for the results screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speakmind/brasa.dart';

void main() {
  group('moodForStars', () {
    test('3 stars cheer, 2 proud, 1 encourage, 0 thinking', () {
      expect(moodForStars(3), BrasaMood.cheer);
      expect(moodForStars(2), BrasaMood.proud);
      expect(moodForStars(1), BrasaMood.encourage);
      expect(moodForStars(0), BrasaMood.thinking);
    });
  });

  group('BrasaFace', () {
    testWidgets('renders every mood without error', (tester) async {
      for (final mood in BrasaMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: BrasaFace(mood: mood)),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(BrasaFace), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    test('mascot name is the single constant', () {
      expect(mascotName, 'Brasa');
    });
  });
}
