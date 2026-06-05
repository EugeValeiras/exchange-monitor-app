import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_thread.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/chat_controller.dart';

/// Side drawer listing previous conversations with open / rename / delete.
class ThreadHistoryDrawer extends StatelessWidget {
  const ThreadHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    return Drawer(
      backgroundColor: AppColors.bgSecondary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Text('Conversaciones',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Nueva conversación',
                    icon: const Icon(Icons.add, color: AppColors.brandAccent),
                    onPressed: () {
                      controller.newConversation();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: controller.loadingThreads && controller.threadList.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : controller.threadList.isEmpty
                      ? const _EmptyHistory()
                      : ListView.builder(
                          itemCount: controller.threadList.length,
                          itemBuilder: (context, i) {
                            final thread = controller.threadList[i];
                            return _ThreadTile(
                              thread: thread,
                              selected: thread.id == controller.currentThreadId,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ThreadSummary thread;
  final bool selected;
  const _ThreadTile({required this.thread, required this.selected});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ChatController>();
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.brandPrimary.withValues(alpha: 0.18),
      title: Text(
        thread.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: thread.lastMessagePreview.isEmpty
          ? null
          : Text(
              thread.lastMessagePreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textTertiary),
        color: AppColors.bgTertiary,
        onSelected: (value) async {
          if (value == 'rename') {
            await _rename(context, controller);
          } else if (value == 'delete') {
            await _confirmDelete(context, controller);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Renombrar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
      onTap: () {
        controller.openThread(thread.id);
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _rename(BuildContext context, ChatController controller) async {
    final input = TextEditingController(text: thread.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Renombrar conversación'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Título'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, input.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await controller.renameThread(thread.id, title);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ChatController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Eliminar conversación'),
        content: Text('¿Eliminar "${thread.title}"? No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteThread(thread.id);
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Todavía no tenés conversaciones.\nEmpezá una nueva.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
