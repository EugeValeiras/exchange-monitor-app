import '../models/chat_thread.dart';
import 'api_service.dart';

/// CRUD over agent chat threads (`/agent/threads`).
class AgentThreadsService {
  final ApiService _api;

  AgentThreadsService(this._api);

  Future<List<ThreadSummary>> list() async {
    final data = await _api.get<List<dynamic>>('/agent/threads');
    return data
        .map((t) => ThreadSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<ThreadDetail> get(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/agent/threads/$id');
    return ThreadDetail.fromJson(data);
  }

  Future<String> create({String? title, String? model}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/agent/threads',
      data: {
        if (title != null) 'title': title,
        if (model != null) 'model': model,
      },
    );
    return data['id'] as String;
  }

  Future<void> rename(String id, String title) async {
    await _api.patch<Map<String, dynamic>>(
      '/agent/threads/$id',
      data: {'title': title},
    );
  }

  Future<void> delete(String id) async {
    await _api.delete<Map<String, dynamic>>('/agent/threads/$id');
  }
}
