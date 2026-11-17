import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

/// An error with a message that can be shown to the user as is.
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
      : _base = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _base;
  final http.Client _client;

  Uri _uri(String path) {
    final uri = Uri.tryParse('$_base$path');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException('服务器地址无效，请到设置里检查');
    }
    return uri;
  }

  /// Uploads a recording and the sentence the user read, returns the scores.
  /// [language] is the code of the language the sentence is in (`en`, `es`).
  Future<Assessment> assess({
    required String audioPath,
    required String text,
    String language = 'en',
  }) {
    return _guard(() async {
      final request = http.MultipartRequest('POST', _uri('/assess'))
        ..fields['text'] = text
        ..fields['language'] = language
        ..files.add(await http.MultipartFile.fromPath('audio', audioPath));
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 90)),
      );
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode != 200) {
        throw ApiException(_detail(body) ?? '服务器错误 ${response.statusCode}');
      }
      return Assessment.fromJson(jsonDecode(body) as Map<String, dynamic>);
    });
  }

  /// A WAV file of the text read aloud by the server's voice.
  Future<Uint8List> speak({required String text, required String language}) {
    return _guard(() async {
      final response = await _client
          .post(
            _uri('/tts'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw ApiException(
          _detail(utf8.decode(response.bodyBytes)) ?? '服务器错误 ${response.statusCode}',
        );
      }
      return response.bodyBytes;
    });
  }

  /// One turn of conversation: sends the history, returns the partner's reply.
  ///
  /// [levelId] and [npcPrompt] follow the levels dev doc §8 contract: when
  /// the server implements them it uses them to role-play the level's NPC.
  /// The current server ignores unknown fields, so sending them is harmless
  /// and the dialogue still works (the NPC's opening line is sent as the
  /// first assistant message by the level page).
  Future<ChatReply> chat({
    required List<ChatMessage> messages,
    required String language,
    String? levelId,
    String? npcPrompt,
  }) {
    return _guard(() async {
      final response = await _client
          .post(
            _uri('/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'language': language,
              'messages': [for (final m in messages) m.toJson()],
              if (levelId != null) 'level_id': levelId,
              if (npcPrompt != null) 'npc_prompt': npcPrompt,
            }),
          )
          .timeout(const Duration(seconds: 90));
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 503) {
        throw const ApiException('服务器还没有配置 AI 聊天，请先设置 SPEAKMIND_AI_API_KEY');
      }
      if (response.statusCode != 200) {
        throw ApiException(_detail(body) ?? '服务器错误 ${response.statusCode}');
      }
      return ChatReply.fromJson(jsonDecode(body) as Map<String, dynamic>);
    });
  }

  /// What the server can do, to confirm the address works.
  Future<ServerInfo> health() {
    return _guard(() async {
      final response =
          await _client.get(_uri('/health')).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw ApiException('服务器错误 ${response.statusCode}');
      }
      return ServerInfo.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    });
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('服务器响应超时');
    } on SocketException {
      throw const ApiException('连不上服务器，请检查地址和网络');
    } on http.ClientException {
      throw const ApiException('连不上服务器，请检查地址和网络');
    } on FormatException {
      throw const ApiException('服务器返回了无法识别的内容');
    }
  }

  static String? _detail(String body) {
    try {
      final json = jsonDecode(body);
      final detail = json is Map ? json['detail'] : null;
      return detail is String ? detail : null;
    } on FormatException {
      return null;
    }
  }
}
