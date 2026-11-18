/// Play history: local-first record of every level attempt, with a
/// server backup via POST /history.
///
/// One attempt = one [HistoryRecord]: completed (finished the level) or
/// abandoned (left the level page before the results step). The local
/// copy in SharedPreferences is the source of truth — it works offline
/// and survives killing the app. The server only ever receives uploads;
/// this version does not download history back (no cross-device restore).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// One level attempt. Field names and shapes follow the server contract
/// exactly — do not rename them (see the /history endpoint).
class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.deviceId,
    required this.levelId,
    required this.startedAt,
    required this.finishedAt,
    required this.stars,
    required this.xpEarned,
    required this.pronAvg,
    required this.challengeScore,
    required this.rounds,
    required this.hintsUsed,
    required this.weakestSentence,
    required this.completed,
    this.synced = false,
  });

  final String id;
  final String deviceId;
  final String levelId;

  /// Kept as DateTime in memory; serialised as UTC ISO8601.
  final DateTime startedAt;
  final DateTime finishedAt;

  /// 0-3 stars (0 for an abandoned attempt).
  final int stars;

  /// XP awarded for this attempt (0 for an abandoned attempt).
  final int xpEarned;

  /// Mean GOP 0-100, null when nothing was scored (abandoned attempt).
  final double? pronAvg;

  /// Challenge-sentence GOP accuracy, null when not attempted.
  final int? challengeScore;

  /// Dialogue rounds actually finished (user turns).
  final int rounds;

  final int hintsUsed;

  /// Spanish text of the weakest shadowing sentence, null when unknown.
  final String? weakestSentence;

  /// False when the level page was left before the results step.
  final bool completed;

  /// Local-only: whether the server has accepted this record.
  /// Never sent to the server.
  final bool synced;

  /// The server contract shape (no `synced` — the server does not need it).
  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'level_id': levelId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'finished_at': finishedAt.toUtc().toIso8601String(),
        'stars': stars,
        'xp_earned': xpEarned,
        'pron_avg': pronAvg,
        'challenge_score': challengeScore,
        'rounds': rounds,
        'hints_used': hintsUsed,
        'weakest_sentence': weakestSentence,
        'completed': completed,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      levelId: json['level_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: DateTime.parse(json['finished_at'] as String),
      stars: (json['stars'] as num).toInt(),
      xpEarned: (json['xp_earned'] as num).toInt(),
      pronAvg: (json['pron_avg'] as num?)?.toDouble(),
      challengeScore: (json['challenge_score'] as num?)?.toInt(),
      rounds: (json['rounds'] as num).toInt(),
      hintsUsed: (json['hints_used'] as num).toInt(),
      weakestSentence: json['weakest_sentence'] as String?,
      completed: json['completed'] as bool? ?? true,
      synced: json['synced'] as bool? ?? false,
    );
  }

  HistoryRecord copyWith({bool? synced}) => HistoryRecord(
        id: id,
        deviceId: deviceId,
        levelId: levelId,
        startedAt: startedAt,
        finishedAt: finishedAt,
        stars: stars,
        xpEarned: xpEarned,
        pronAvg: pronAvg,
        challengeScore: challengeScore,
        rounds: rounds,
        hintsUsed: hintsUsed,
        weakestSentence: weakestSentence,
        completed: completed,
        synced: synced ?? this.synced,
      );
}

/// Generates a random UUID v4 string (no new dependency).
String newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // Version 4 + RFC 4122 variant bits.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex =
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

/// Local play-history store, persisted in SharedPreferences.
///
/// The whole list is one JSON string under [recordsKey]; the anonymous
/// device id (random UUID, no personal data, no accounts) lives under
/// [deviceIdKey] and never changes once generated.
class HistoryStore extends ChangeNotifier {
  HistoryStore(this._prefs) {
    _ensureDeviceId();
  }

  static const recordsKey = 'history_records_v1';
  static const deviceIdKey = 'history_device_id';

  /// Cap: oldest records drop off first when the list grows past this.
  static const maxRecords = 500;

  final SharedPreferences _prefs;

  static Future<HistoryStore> load() async =>
      HistoryStore(await SharedPreferences.getInstance());

  List<HistoryRecord> get _stored {
    final raw = _prefs.getString(recordsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>)
            HistoryRecord.fromJson(item)
          else if (item is Map)
            HistoryRecord.fromJson(item.cast<String, dynamic>()),
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> _save(List<HistoryRecord> records) => _prefs.setString(
        recordsKey,
        jsonEncode([
          for (final r in records)
            {...r.toJson(), 'synced': r.synced},
        ]),
      );

  void _ensureDeviceId() {
    if (_prefs.getString(deviceIdKey) == null) {
      // Fire-and-forget: SharedPreferences updates its in-memory cache
      // synchronously, so the getter below reads the new id right away.
      unawaited(_prefs.setString(deviceIdKey, newUuidV4()));
    }
  }

  /// Anonymous device id, generated once on first launch and stable after.
  String get deviceId {
    _ensureDeviceId();
    return _prefs.getString(deviceIdKey)!;
  }

  /// All records, oldest first.
  List<HistoryRecord> get records => List.unmodifiable(_stored);

  /// The [n] most recent records, newest first.
  List<HistoryRecord> recent(int n) {
    final all = _stored;
    if (all.length <= n) return all.reversed.toList();
    return all.sublist(all.length - n).reversed.toList();
  }

  /// Records not yet accepted by the server, oldest first.
  List<HistoryRecord> unsynced() =>
      _stored.where((r) => !r.synced).toList();

  /// Records one attempt and returns it. Trims the oldest records when
  /// the list grows past [maxRecords]. The new record starts unsynced.
  Future<HistoryRecord> record({
    required String levelId,
    required DateTime startedAt,
    required DateTime finishedAt,
    required int stars,
    required int xpEarned,
    required double? pronAvg,
    required int? challengeScore,
    required int rounds,
    required int hintsUsed,
    required String? weakestSentence,
    required bool completed,
  }) async {
    final entry = HistoryRecord(
      id: newUuidV4(),
      deviceId: deviceId,
      levelId: levelId,
      startedAt: startedAt,
      finishedAt: finishedAt,
      stars: stars,
      xpEarned: xpEarned,
      pronAvg: pronAvg,
      challengeScore: challengeScore,
      rounds: rounds,
      hintsUsed: hintsUsed,
      weakestSentence: weakestSentence,
      completed: completed,
    );
    final all = _stored..add(entry);
    if (all.length > maxRecords) {
      all.removeRange(0, all.length - maxRecords);
    }
    await _save(all);
    notifyListeners();
    return entry;
  }

  /// Marks the given record ids as synced. Returns how many were marked.
  Future<int> markSynced(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return 0;
    var marked = 0;
    final all = <HistoryRecord>[];
    for (final r in _stored) {
      if (!r.synced && wanted.contains(r.id)) {
        marked++;
        all.add(r.copyWith(synced: true));
      } else {
        all.add(r);
      }
    }
    if (marked > 0) {
      await _save(all);
      notifyListeners();
    }
    return marked;
  }

  /// Uploads unsynced records to POST /history and marks the accepted
  /// ones synced. Never throws: any failure just leaves the records
  /// unsynced for the next attempt, so sync can never block gameplay.
  /// Returns how many records the server accepted.
  Future<int> sync(ApiClient client) async {
    final pending = unsynced();
    if (pending.isEmpty) return 0;
    try {
      final accepted = await client.uploadHistory(
        deviceId: deviceId,
        records: [for (final r in pending) r.toJson()],
      );
      if (accepted <= 0) return 0;
      final ids = pending.take(accepted).map((r) => r.id);
      return await markSynced(ids);
    } catch (_) {
      return 0;
    }
  }
}
