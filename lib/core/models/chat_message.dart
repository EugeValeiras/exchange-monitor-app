/// A tool call performed by the agent during a turn, with its result once it
/// arrives. Mirrors `ChatToolRecord` / `PersistedToolRecord` in the backend.
class ToolUseRecord {
  final String id;
  final String name;
  final dynamic input;
  String? result;
  bool isError;

  ToolUseRecord({
    required this.id,
    required this.name,
    this.input,
    this.result,
    this.isError = false,
  });

  factory ToolUseRecord.fromJson(Map<String, dynamic> json) => ToolUseRecord(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        input: json['input'],
        result: json['result'] as String?,
        isError: json['isError'] as bool? ?? false,
      );
}

/// A single message in a chat thread. Used both for persisted messages loaded
/// from the API and for the in-flight assistant turn being streamed.
class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  String text;
  final List<ToolUseRecord> tools;
  String? error;
  bool streaming;

  ChatMessage({
    required this.id,
    required this.role,
    this.text = '',
    List<ToolUseRecord>? tools,
    this.error,
    this.streaming = false,
  }) : tools = tools ?? [];

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: json['role'] as String? ?? 'assistant',
        text: json['text'] as String? ?? '',
        tools: (json['tools'] as List<dynamic>? ?? [])
            .map((t) => ToolUseRecord.fromJson(t as Map<String, dynamic>))
            .toList(),
        error: json['error'] as String?,
      );
}
