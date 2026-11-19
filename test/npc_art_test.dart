import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speakmind/npc_art.dart';
import 'package:speakmind/widgets/typewriter_text.dart';

void main() {
  group('npcPortraitAsset', () {
    test('all 18 named NPCs map to a portrait', () {
      const names = [
        'Carmen',
        'Pablo',
        'Don José',
        'Lucía',
        'Sofía',
        'Elena',
        'Valentina',
        'Diego',
        'Mateo',
        'Martín',
        'Andrés',
        'Camila',
        'Mariana',
        'Marta',
        'Raúl',
        'Rosa',
        'Teresa',
        'Toño',
      ];
      for (final name in names) {
        final asset = npcPortraitAsset(name);
        expect(asset, isNotNull, reason: name);
        expect(asset, startsWith('assets/npc/'));
        expect(asset, endsWith('.webp'));
      }
    });

    test('accents and case do not matter', () {
      expect(npcPortraitAsset('don josé'), 'assets/npc/don_jose.webp');
      expect(npcPortraitAsset('LUCÍA'), 'assets/npc/lucia.webp');
      expect(npcPortraitAsset('  Martín  '), 'assets/npc/martin.webp');
    });

    test('unknown or generic names have no portrait', () {
      expect(npcPortraitAsset('对话伙伴'), isNull);
      expect(npcPortraitAsset(''), isNull);
      expect(npcPortraitAsset('Nobody'), isNull);
    });
  });

  group('worldSceneAsset', () {
    test('eight worlds, one scene each', () {
      const expected = {
        1: 'assets/worlds/w1_madrid.webp',
        2: 'assets/worlds/w2_barcelona.webp',
        3: 'assets/worlds/w3_mexico.webp',
        4: 'assets/worlds/w4_andes.webp',
        5: 'assets/worlds/w5_buenosaires.webp',
        6: 'assets/worlds/w6_camino.webp',
        7: 'assets/worlds/w7_filmcity.webp',
        8: 'assets/worlds/w8_globe.webp',
      };
      for (final entry in expected.entries) {
        expect(worldSceneAsset(entry.key), entry.value);
      }
    });
  });

  group('TypewriterText', () {
    testWidgets('reveals text over time, tap finishes at once', (
      tester,
    ) async {
      const text = '¡Hola! Bienvenido a Madrid.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TypewriterText(text: text)),
        ),
      );
      // Nothing shown yet on the first frame.
      expect(find.text(text), findsNothing);
      // Halfway through: some characters visible, not the full line.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(text), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
      // Tap to finish at once.
      await tester.tap(find.byType(TypewriterText));
      await tester.pump();
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('restarts when the text changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TypewriterText(text: 'Hola.')),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Hola.'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TypewriterText(text: 'Adiós.')),
        ),
      );
      await tester.pump();
      expect(find.text('Adiós.'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Adiós.'), findsOneWidget);
    });
  });
}
