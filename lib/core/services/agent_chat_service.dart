import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/agent_event.dart';
import 'api_service.dart';

class ChatStreamOptions {
  final String message;
  final String? threadId;
  final String? sessionId;
  final String? model; // 'sonnet' | 'opus' | 'haiku'

  const ChatStreamOptions({
    required this.message,
    this.threadId,
    this.sessionId,
    this.model,
  });

  Map<String, dynamic> toBody() => {
        'message': message,
        if (threadId != null) 'threadId': threadId,
        if (sessionId != null) 'sessionId': sessionId,
        if (model != null) 'model': model,
      };
}

/// Streams a chat turn from the backend agent.
///
/// Tries the SSE endpoint (`POST /agent/chat`) first and falls back to the
/// buffered sync endpoint (`POST /agent/chat/sync`) if streaming fails.
class AgentChatService {
  final ApiService _api;
  final Dio _dio;

  AgentChatService(this._api)
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.instance.apiBaseUrl,
            connectTimeout: const Duration(seconds: 30),
            // No receive timeout: an agent turn can take minutes to stream.
            receiveTimeout: Duration.zero,
          ),
        );

  String? get _token => _api.authToken;

  /// Yields agent events as they arrive. Pass [cancelToken] to abort the turn.
  Stream<AgentEvent> stream(
    ChatStreamOptions opts, {
    CancelToken? cancelToken,
  }) async* {
    final token = _token;
    if (token == null) {
      throw Exception('No hay token de autenticación. Hacé login.');
    }

    Response<ResponseBody>? response;
    try {
      response = await _dio.post<ResponseBody>(
        '/agent/chat',
        data: opts.toBody(),
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
            'Content-Type': 'application/json',
          },
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (kDebugMode) {
        debugPrint('[AgentChat] streaming failed, trying sync fallback: $e');
      }
      yield* _streamSync(opts, cancelToken: cancelToken);
      return;
    }

    final body = response.data;
    if (body == null) {
      yield* _streamSync(opts, cancelToken: cancelToken);
      return;
    }

    final buffer = <int>[];
    try {
      await for (final chunk in body.stream) {
        buffer.addAll(chunk);
        // SSE events are separated by a blank line (\n\n).
        var sep = _indexOfDoubleNewline(buffer);
        while (sep != -1) {
          final block = utf8.decode(buffer.sublist(0, sep), allowMalformed: true);
          buffer.removeRange(0, sep + 2);
          for (final event in _parseBlock(block)) {
            yield event;
          }
          sep = _indexOfDoubleNewline(buffer);
        }
      }
      // Flush any trailing block without a final separator.
      if (buffer.isNotEmpty) {
        final block = utf8.decode(buffer, allowMalformed: true);
        for (final event in _parseBlock(block)) {
          yield event;
        }
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) rethrow;
    }
  }

  /// Buffered fallback: gets the whole turn at once and replays its events.
  Stream<AgentEvent> _streamSync(
    ChatStreamOptions opts, {
    CancelToken? cancelToken,
  }) async* {
    final token = _token;
    if (token == null) {
      throw Exception('No hay token de autenticación. Hacé login.');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/agent/chat/sync',
      data: opts.toBody(),
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );

    final events = response.data?['events'] as List<dynamic>? ?? [];
    for (final raw in events) {
      final event = AgentEvent.fromJson(raw as Map<String, dynamic>);
      if (event != null) yield event;
    }
  }

  /// Parses one SSE block, extracting `data:` lines into events.
  Iterable<AgentEvent> _parseBlock(String block) sync* {
    for (final line in block.split('\n')) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final event = AgentEvent.fromJson(json);
        if (event != null) yield event;
      } catch (_) {
        // skip malformed payloads
      }
    }
  }

  int _indexOfDoubleNewline(List<int> bytes) {
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] == 0x0A && bytes[i + 1] == 0x0A) return i;
    }
    return -1;
  }
}
