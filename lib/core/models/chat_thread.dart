import 'chat_message.dart';

/// Summary of a chat thread as returned by `GET /agent/threads`.
class ThreadSummary {
  final String id;
  final String title;
  final String model; // 'sonnet' | 'opus' | 'haiku'
  final String? claudeSessionId;
  final int messageCount;
  final String lastMessagePreview;
  final double costUsd;
  final DateTime updatedAt;
  final DateTime createdAt;

  ThreadSummary({
    required this.id,
    required this.title,
    required this.model,
    this.claudeSessionId,
    required this.messageCount,
    required this.lastMessagePreview,
    required this.costUsd,
    required this.updatedAt,
    required this.createdAt,
  });

  factory ThreadSummary.fromJson(Map<String, dynamic> json) => ThreadSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Conversación',
        model: json['model'] as String? ?? 'sonnet',
        claudeSessionId: json['claudeSessionId'] as String?,
        messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
        lastMessagePreview: json['lastMessagePreview'] as String? ?? '',
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
        updatedAt: _parseDate(json['updatedAt']),
        createdAt: _parseDate(json['createdAt']),
      );
}

/// Full thread with messages as returned by `GET /agent/threads/:id`.
class ThreadDetail {
  final String id;
  final String title;
  final String model;
  final String? claudeSessionId;
  final List<ChatMessage> messages;
  final double costUsd;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final DateTime updatedAt;
  final DateTime createdAt;

  ThreadDetail({
    required this.id,
    required this.title,
    required this.model,
    this.claudeSessionId,
    required this.messages,
    required this.costUsd,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedTokens,
    required this.updatedAt,
    required this.createdAt,
  });

  factory ThreadDetail.fromJson(Map<String, dynamic> json) => ThreadDetail(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Conversación',
        model: json['model'] as String? ?? 'sonnet',
        claudeSessionId: json['claudeSessionId'] as String?,
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
        cachedTokens: (json['cachedTokens'] as num?)?.toInt() ?? 0,
        updatedAt: _parseDate(json['updatedAt']),
        createdAt: _parseDate(json['createdAt']),
      );
}

DateTime _parseDate(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}
