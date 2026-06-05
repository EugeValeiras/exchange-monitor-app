import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/agent_event.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/chat_thread.dart';
import '../../../core/services/agent_chat_service.dart';
import '../../../core/services/agent_threads_service.dart';

enum AgentModel { sonnet, opus, haiku }

extension AgentModelName on AgentModel {
  String get id => name; // 'sonnet' | 'opus' | 'haiku'
  String get label => switch (this) {
        AgentModel.sonnet => 'Sonnet',
        AgentModel.opus => 'Opus',
        AgentModel.haiku => 'Haiku',
      };
}

/// Owns the chat UI state: thread list, the open conversation, and the
/// in-flight streaming turn.
class ChatController extends ChangeNotifier {
  final AgentChatService _chat;
  final AgentThreadsService _threads;

  ChatController(this._chat, this._threads);

  // ── Thread list ──────────────────────────────────────────────────────────
  List<ThreadSummary> _threadList = [];
  List<ThreadSummary> get threadList => _threadList;

  bool _loadingThreads = false;
  bool get loadingThreads => _loadingThreads;

  // ── Open conversation ──────────────────────────────────────────────────────
  String? _currentThreadId;
  String? get currentThreadId => _currentThreadId;

  String? _claudeSessionId;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _loadingThread = false;
  bool get loadingThread => _loadingThread;

  AgentModel _model = AgentModel.sonnet;
  AgentModel get model => _model;
  set model(AgentModel value) {
    _model = value;
    notifyListeners();
  }

  double _costUsd = 0;
  double get costUsd => _costUsd;

  // ── Streaming ──────────────────────────────────────────────────────────────
  bool _streaming = false;
  bool get streaming => _streaming;

  StreamSubscription<AgentEvent>? _sub;
  CancelToken? _cancelToken;

  String? _error;
  String? get error => _error;

  // ── Thread list operations ─────────────────────────────────────────────────
  Future<void> loadThreads() async {
    _loadingThreads = true;
    notifyListeners();
    try {
      _threadList = await _threads.list();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingThreads = false;
      notifyListeners();
    }
  }

  /// Starts a fresh, unsaved conversation. The thread is created on the server
  /// when the first message is sent.
  void newConversation() {
    if (_streaming) abort();
    _currentThreadId = null;
    _claudeSessionId = null;
    _costUsd = 0;
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> openThread(String id) async {
    if (_streaming) abort();
    _loadingThread = true;
    _currentThreadId = id;
    _messages.clear();
    _error = null;
    notifyListeners();
    try {
      final detail = await _threads.get(id);
      _claudeSessionId = detail.claudeSessionId;
      _costUsd = detail.costUsd;
      _model = AgentModel.values.firstWhere(
        (m) => m.id == detail.model,
        orElse: () => AgentModel.sonnet,
      );
      _messages
        ..clear()
        ..addAll(detail.messages);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingThread = false;
      notifyListeners();
    }
  }

  Future<void> renameThread(String id, String title) async {
    await _threads.rename(id, title);
    await loadThreads();
  }

  Future<void> deleteThread(String id) async {
    await _threads.delete(id);
    if (_currentThreadId == id) newConversation();
    await loadThreads();
  }

  // ── Sending a message ───────────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _streaming) return;

    _error = null;
    _messages.add(ChatMessage(
      id: _randomId(),
      role: 'user',
      text: trimmed,
    ));

    final assistant = ChatMessage(
      id: _randomId(),
      role: 'assistant',
      streaming: true,
    );
    _messages.add(assistant);

    _streaming = true;
    notifyListeners();

    _cancelToken = CancelToken();
    final completer = Completer<void>();

    _sub = _chat
        .stream(
          ChatStreamOptions(
            message: trimmed,
            threadId: _currentThreadId,
            sessionId: _currentThreadId == null ? null : _claudeSessionId,
            model: _model.id,
          ),
          cancelToken: _cancelToken,
        )
        .listen(
      (event) => _handleEvent(event, assistant),
      onError: (Object e) {
        assistant.error = e.toString();
        assistant.streaming = false;
        _finishStream();
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        assistant.streaming = false;
        _finishStream();
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    // Refresh the thread list so the new/updated thread shows up.
    await loadThreads();
  }

  void _handleEvent(AgentEvent event, ChatMessage assistant) {
    switch (event) {
      case ThreadEvent(:final threadId):
        _currentThreadId ??= threadId;
      case SessionEvent(:final sessionId):
        _claudeSessionId = sessionId;
      case TextEvent(:final text):
        assistant.text += text;
      case ToolUseEvent(:final id, :final name, :final input):
        assistant.tools.add(ToolUseRecord(id: id, name: name, input: input));
      case ToolResultEvent(:final toolUseId, :final content, :final isError):
        for (final tool in assistant.tools) {
          if (tool.id == toolUseId) {
            tool.result = content;
            tool.isError = isError;
            break;
          }
        }
      case UsageEvent(:final costUsd):
        if (costUsd > 0) _costUsd = costUsd;
      case DoneEvent(:final sessionId):
        if (sessionId != null) _claudeSessionId = sessionId;
      case ErrorEvent(:final message):
        assistant.error = message;
    }
    notifyListeners();
  }

  void _finishStream() {
    _streaming = false;
    _sub?.cancel();
    _sub = null;
    _cancelToken = null;
    notifyListeners();
  }

  /// Aborts the in-flight turn, keeping whatever was streamed so far.
  void abort() {
    if (!_streaming) return;
    _cancelToken?.cancel('aborted by user');
    for (final m in _messages) {
      if (m.streaming) m.streaming = false;
    }
    _finishStream();
  }

  String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${identityHashCode(Object()).toRadixString(36)}';

  @override
  void dispose() {
    _sub?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
