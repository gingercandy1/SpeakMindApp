import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/pages/practice_page.dart';
import 'package:speakmind/settings.dart';

void main() {
  testWidgets('practice page fits a small phone and steps through sentences', (tester) async {
    // No recorder, player or speech engine exists in tests: answer every
    // plugin call with null. Flutter's own channels keep their handlers.
    tester.binding.defaultBinaryMessenger.allMessagesHandler = (channel, handler, message) async {
      if (channel.startsWith('flutter/')) return handler?.call(message);
      return const StandardMethodCodec().encodeSuccessEnvelope(null);
    };
    addTearDown(() => tester.binding.defaultBinaryMessenger.allMessagesHandler = null);

    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: PracticePage(settings: settings)));
    await tester.pump();

    expect(find.text(builtInSentences[0]), findsOneWidget);
    expect(find.text('第 1 句 / 共 ${builtInSentences.length} 句'), findsOneWidget);
    expect(find.text('点麦克风开始朗读'), findsOneWidget);

    await tester.tap(find.byTooltip('下一句'));
    await tester.pump();
    expect(find.text(builtInSentences[1]), findsOneWidget);

    await tester.tap(find.byTooltip('上一句'));
    await tester.tap(find.byTooltip('上一句'));
    await tester.pump();
    expect(find.text(builtInSentences.last), findsOneWidget);

    await tester.tap(find.byTooltip('选择句子'));
    await tester.pumpAndSettle();
    expect(find.text('添加自己的英文句子'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A sentence of my own.');
    await tester.tap(find.byTooltip('添加'));
    await tester.pumpAndSettle();
    expect(find.text('A sentence of my own.'), findsOneWidget);
    expect(find.text('第 1 句 / 共 ${builtInSentences.length + 1} 句'), findsOneWidget);

    // Switching to Spanish shows the Spanish sentences.
    await tester.tap(find.text('ES'));
    await tester.pumpAndSettle();
    expect(find.text(builtInSentencesEs[0]), findsOneWidget);
    expect(find.text('第 1 句 / 共 ${builtInSentencesEs.length} 句'), findsOneWidget);
  });
}
