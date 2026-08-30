import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/em_tokens.dart';
import '../providers/chat_controller.dart';
import '../widgets/message_bubble.dart';
import '../widgets/thread_history_drawer.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _threadsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_threadsLoaded) {
        _threadsLoaded = true;
        context.read<ChatController>().loadThreads();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    final controller = context.read<ChatController>();
    _scrollToBottom();
    await controller.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: EmColors.bg,
      endDrawer: const ThreadHistoryDrawer(),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: EmColors.textSecondary, size: 20),
            SizedBox(width: 8),
            Text('Agente'),
          ],
        ),
        actions: [
          _ModelSelector(),
          Consumer<ChatController>(
            builder: (context, c, _) => IconButton(
              tooltip: 'Nueva conversación',
              icon: const Icon(Icons.edit_square),
              onPressed: c.streaming ? null : c.newConversation,
            ),
          ),
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatController>(
              builder: (context, controller, _) {
                if (controller.loadingThread) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.messages.isEmpty) {
                  return const _EmptyChat();
                }
                // Auto-scroll as the assistant streams.
                if (controller.streaming) _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, i) =>
                      MessageBubble(message: controller.messages[i]),
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    return PopupMenuButton<AgentModel>(
      enabled: !controller.streaming,
      color: EmColors.surfaceHigh,
      tooltip: 'Modelo',
      onSelected: (m) => controller.model = m,
      itemBuilder: (_) => AgentModel.values
          .map((m) => PopupMenuItem(value: m, child: Text(m.label)))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.model.label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: EmColors.textSecondary),
            ),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: EmColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    return Container(
      decoration: const BoxDecoration(
        color: EmColors.surfaceHigh,
        border: Border(top: BorderSide(color: EmColors.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  enabled: !chat.loadingThread,
                  style: const TextStyle(color: EmColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Preguntale algo al agente…',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              chat.streaming
                  ? _CircleButton(
                      icon: Icons.stop,
                      color: EmColors.down,
                      onTap: chat.abort,
                    )
                  : _CircleButton(
                      icon: Icons.arrow_upward,
                      color: EmColors.textPrimary,
                      onTap: onSend,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: EmColors.bg, size: 20),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 56, color: EmColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Tu agente de portfolio',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: EmColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preguntá por tus balances, P&L, precios o\nanálisis de mercado en lenguaje natural.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EmColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in const [
                  '¿Cómo viene mi portfolio?',
                  '¿Cuánto tengo en BTC?',
                  'Analizá el mercado de ETH',
                  'Mi P&L de este mes',
                ])
                  _SuggestionChip(text: s),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: EmColors.surfaceHigh,
      side: const BorderSide(color: EmColors.stroke),
      onPressed: () => context.read<ChatController>().sendMessage(text),
    );
  }
}
