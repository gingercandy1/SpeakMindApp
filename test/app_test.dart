import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/api.dart';
import 'package:speakmind/models.dart';
import 'package:speakmind/settings.dart';
import 'package:speakmind/widgets/result_view.dart';

/// Shape of a real `POST /assess` response from the server.
const _response = {
  'accuracy': 89,
  'level': 'good',
  'fluency': {
    'speaking_seconds': 1.52,
    'phonemes_per_second': 13.8,
    'pause_count': 1,
    'pauses': [
      {'after': 'good', 'seconds': 0.6},
    ],
  },
  'audio_seconds': 2.62,
  'words': [
    {
      'word': 'good',
      'score': 84,
      'level': 'good',
      'start': 1.2,
      'end': 1.36,
      'phonemes': [
        {'ipa': 'ɡ', 'score': 97, 'level': 'good', 'start': 1.2, 'end': 1.22},
        {'ipa': 'ʊ', 'score': 57, 'level': 'fair', 'start': 1.26, 'end': 1.28, 'heard': 'ə'},
        {'ipa': 'd', 'score': 99, 'level': 'good', 'start': 1.34, 'end': 1.36},
      ],
    },
    {
      'word': 'idea',
      'score': 64,
      'level': 'fair',
      'start': 1.42,
      'end': 1.64,
      'phonemes': [
        {'ipa': 'aɪ', 'score': 92, 'level': 'good', 'start': 1.42, 'end': 1.44},
        {'ipa': 'iə', 'score': 2, 'level': 'poor', 'start': 1.6, 'end': 1.64, 'heard': 'ɪ'},
      ],
    },
    {
      'word': 'xyz',
      'score': null,
      'level': null,
      'start': null,
      'end': null,
      'phonemes': <Object>[],
    },
  ],
  'text': 'good idea xyz',
  'processing_seconds': 1.11,
};

void main() {
  test('parses a server response', () {
    final result = Assessment.fromJson(_response);

    expect(result.accuracy, 89);
    expect(result.level, Level.good);
    expect(result.fluency.phonemesPerSecond, 13.8);
    expect(result.fluency.pauses.single.after, 'good');
    expect(result.words[1].phonemes[1].heard, 'ɪ');
    expect(result.words[1].phonemes[1].level, Level.poor);
    expect(result.words[2].score, isNull);
    expect(result.words[2].level, Level.unknown);
  });

  group('ApiClient', () {
    test('uploads the sentence and audio, returns the assessment', () async {
      late http.BaseRequest sent;
      final client = MockClient.streaming((request, body) async {
        sent = request;
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(_response))),
          200,
        );
      });

      // A trailing slash in the saved address must not break the URL.
      final result = await ApiClient('http://host:8000/', client: client)
          .assess(audioPath: 'test/app_test.dart', text: 'good idea');

      expect(sent.url.toString(), 'http://host:8000/assess');
      final multipart = sent as http.MultipartRequest;
      expect(multipart.fields['text'], 'good idea');
      expect(multipart.files.single.field, 'audio');
      expect(result.words.first.word, 'good');
    });

    test('shows the server\'s error detail', () async {
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"detail":"audio is too short for this sentence"}')),
          422,
        );
      });

      expect(
        ApiClient('http://host:8000', client: client)
            .assess(audioPath: 'test/app_test.dart', text: 'hi'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'audio is too short for this sentence',
        )),
      );
    });

    test('rejects an address without a scheme', () {
      expect(
        ApiClient('192.168.1.10:8000').health(),
        throwsA(isA<ApiException>()),
      );
    });

    test('sends the language with an assessment', () async {
      late http.MultipartRequest sent;
      final client = MockClient.streaming((request, body) async {
        sent = request as http.MultipartRequest;
        await body.drain<void>();
        return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(_response))), 200);
      });

      await ApiClient('http://host:8000', client: client)
          .assess(audioPath: 'test/app_test.dart', text: 'Hola', language: 'es');
      expect(sent.fields['language'], 'es');
    });

    test('speak posts the text and returns the audio', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes([1, 2, 3], 200);
      });

      final wav = await ApiClient('http://host:8000', client: client)
          .speak(text: 'Hola', language: 'es');
      expect(sent.url.path, '/tts');
      expect(jsonDecode(sent.body), {'text': 'Hola', 'language': 'es'});
      expect(wav, [1, 2, 3]);
    });

    test('chat sends the history and reads the reply and tip', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({'reply': 'I am fine. And you?', 'tip': '应说 I am fine'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final reply = await ApiClient('http://host:8000', client: client).chat(
        messages: const [
          ChatMessage(role: 'assistant', content: 'Hi!'),
          ChatMessage(role: 'user', content: 'I fine'),
        ],
        language: 'en',
      );
      expect(jsonDecode(sent.body), {
        'language': 'en',
        'messages': [
          {'role': 'assistant', 'content': 'Hi!'},
          {'role': 'user', 'content': 'I fine'},
        ],
      });
      expect(reply.reply, 'I am fine. And you?');
      expect(reply.tip, '应说 I am fine');
    });

    test('chat explains when the server has no AI configured', () {
      final client = MockClient((_) async => http.Response('{"detail":"x"}', 503));
      expect(
        ApiClient('http://host:8000', client: client).chat(
          messages: const [ChatMessage(role: 'user', content: 'hi')],
          language: 'en',
        ),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('AI 聊天'))),
      );
    });

    test('health reports voices and chat', () async {
      final client = MockClient((_) async => http.Response(
            '{"status":"ok","model":"m","languages":["en","es"],"tts":["en","es"],"chat":true}',
            200,
          ));
      final info = await ApiClient('http://host:8000', client: client).health();
      expect(info.model, 'm');
      expect(info.ttsLanguages, ['en', 'es']);
      expect(info.chat, isTrue);
    });
  });

  test('each language keeps its own sentences', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();
    expect(settings.language.code, 'en');

    await settings.addSentence('My English sentence.');
    await settings.setLanguage(languages.last);
    expect(settings.language.code, 'es');
    expect(settings.sentences, builtInSentencesEs);

    await settings.addSentence('Mi frase.');
    expect(settings.sentences.first, 'Mi frase.');
    await settings.setLanguage(languages.first);
    expect(settings.sentences.first, 'My English sentence.');
    expect(settings.sentences, isNot(contains('Mi frase.')));
  });

  test('custom sentences are stored and listed first', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();

    expect(settings.serverUrl, SettingsStore.defaultServerUrl);
    await settings.addSentence('  My own sentence.  ');
    await settings.addSentence('My own sentence.');
    expect(settings.sentences.first, 'My own sentence.');
    expect(settings.customSentences, hasLength(1));

    await settings.removeSentence('My own sentence.');
    expect(settings.sentences, builtInSentences);
  });

  testWidgets('ResultView shows scores and the phonemes of the tapped word', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ResultView(
                result: Assessment.fromJson(_response),
                selectedWord: selected,
                onSelectWord: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('89'), findsOneWidget);
    expect(find.text('停顿 1 次'), findsNothing); // joined with the speech rate
    expect(find.textContaining('停顿 1 次'), findsOneWidget);
    expect(find.text('/iə/'), findsNothing);

    await tester.tap(find.text('idea'));
    await tester.pump();

    expect(find.text('idea · 64 分'), findsOneWidget);
    expect(find.text('/iə/'), findsOneWidget);
    expect(find.text('像 /ɪ/'), findsOneWidget);

    await tester.tap(find.text('xyz'));
    await tester.pump();
    expect(find.text('这个词暂时无法评分'), findsOneWidget);
  });
}
