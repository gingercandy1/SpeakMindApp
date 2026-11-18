/// History tests: store round-trip, 500 cap, sync marking, stable
/// device id, and the POST /history sync path (success + failure).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakmind/api.dart';
import 'package:speakmind/history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HistoryStore history;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    history = await HistoryStore.load();
  });

  Future<HistoryRecord> recordOne({
    String levelId = '1-1',
    bool completed = true,
  }) =>
      history.record(
        levelId: levelId,
        startedAt: DateTime.utc(2026, 11, 18, 10, 0, 0),
        finishedAt: DateTime.utc(2026, 11, 18, 10, 4, 30),
        stars: 3,
        xpEarned: 20,
        pronAvg: 78.5,
        challengeScore: 92,
        rounds: 4,
        hintsUsed: 1,
        weakestSentence: '¿Dónde está la estación?',
        completed: completed,
      );

  test('device id is a stable UUID v4 across reloads', () async {
    final first = history.deviceId;
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    final reloaded = await HistoryStore.load();
    expect(reloaded.deviceId, first);
  });

  test('record survives reload with all contract fields', () async {
    final saved = await recordOne();
    final reloaded = await HistoryStore.load();
    expect(reloaded.records, hasLength(1));
    final back = reloaded.records.single;
    expect(back.id, saved.id);
    expect(back.deviceId, history.deviceId);
    expect(back.levelId, '1-1');
    expect(back.startedAt.toUtc().toIso8601String(),
        '2026-11-18T10:00:00.000Z');
    expect(back.finishedAt.toUtc().toIso8601String(),
        '2026-11-18T10:04:30.000Z');
    expect(back.stars, 3);
    expect(back.xpEarned, 20);
    expect(back.pronAvg, 78.5);
    expect(back.challengeScore, 92);
    expect(back.rounds, 4);
    expect(back.hintsUsed, 1);
    expect(back.weakestSentence, '¿Dónde está la estación?');
    expect(back.completed, isTrue);
    expect(back.synced, isFalse);
    // The server payload follows the contract exactly (no local `synced`).
    final payload = back.toJson();
    expect(payload.keys,
        containsAll(['id', 'device_id', 'level_id', 'started_at',
            'finished_at', 'stars', 'xp_earned', 'pron_avg',
            'challenge_score', 'rounds', 'hints_used', 'weakest_sentence',
            'completed']));
    expect(payload.containsKey('synced'), isFalse);
  });

  test('recent(n) returns the newest first', () async {
    await recordOne(levelId: '1-1');
    await recordOne(levelId: '1-2');
    await recordOne(levelId: '1-3');
    final recent = history.recent(2);
    expect([for (final r in recent) r.levelId], ['1-3', '1-2']);
  });

  test('cap trims the oldest records past 500', () async {
    await recordOne(levelId: 'old-1');
    for (var i = 0; i < 504; i++) {
      await recordOne(levelId: '1-1');
    }
    expect(history.records, hasLength(500));
    expect(history.records.any((r) => r.levelId == 'old-1'), isFalse);
  });

  test('markSynced clears unsynced', () async {
    final first = await recordOne(levelId: '1-1');
    await recordOne(levelId: '1-2');
    expect(history.unsynced(), hasLength(2));
    expect(await history.markSynced([first.id]), 1);
    expect(history.unsynced(), hasLength(1));
    expect(history.unsynced().single.levelId, '1-2');
    await history.markSynced(history.unsynced().map((r) => r.id));
    expect(history.unsynced(), isEmpty);
    expect(history.records, hasLength(2));
  });

  test('sync uploads unsynced and marks them synced', () async {
    await recordOne(levelId: '1-1');
    await recordOne(levelId: '1-2');
    Map<String, dynamic>? seenBody;
    final client = ApiClient(
      'http://127.0.0.1:9',
      client: MockClient((request) async {
        expect(request.url.path, '/history');
        seenBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"accepted": 2}', 200);
      }),
    );
    expect(await history.sync(client), 2);
    expect(history.unsynced(), isEmpty);
    expect(seenBody!['device_id'], history.deviceId);
    final sent = seenBody!['records'] as List<dynamic>;
    expect(sent, hasLength(2));
    expect((sent.first as Map<String, dynamic>)['level_id'], '1-1');
  });

  test('sync failure leaves records unsynced and never throws', () async {
    await recordOne();
    final failing = ApiClient(
      'http://127.0.0.1:9',
      client: MockClient((_) async => http.Response('boom', 500)),
    );
    expect(await history.sync(failing), 0);
    expect(history.unsynced(), hasLength(1));

    final unreachable = ApiClient(
      'http://127.0.0.1:9',
      client: MockClient(
        (_) async => throw http.ClientException('no network'),
      ),
    );
    expect(await history.sync(unreachable), 0);
    expect(history.unsynced(), hasLength(1));
  });

  test('sync with nothing pending does not call the server', () async {
    var called = false;
    final client = ApiClient(
      'http://127.0.0.1:9',
      client: MockClient((_) async {
        called = true;
        return http.Response('{"accepted": 0}', 200);
      }),
    );
    expect(await history.sync(client), 0);
    expect(called, isFalse);
  });
}
