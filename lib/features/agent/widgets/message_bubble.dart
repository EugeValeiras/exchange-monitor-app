import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_theme.dart';
import 'tool_call_tile.dart';

/// Renders a single chat message. User messages are right-aligned bubbles;
/// assistant messages render Markdown plus any tool calls.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return message.isUser ? _buildUser(context) : _buildAssistant(context);
  }

  Widget _buildUser(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.brandPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildAssistant(BuildContext context) {
    final hasText = message.text.trim().isNotEmpty;
    final showThinking =
        message.streaming && !hasText && message.tools.isEmpty;

    return Container(
      margin: const EdgeInsets.only(right: 24, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined,
                  size: 16, color: AppColors.brandAccent),
              const SizedBox(width: 6),
              Text(
                'Agente',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final tool in message.tools) ToolCallTile(tool: tool),
          if (message.tools.isNotEmpty && hasText) const SizedBox(height: 6),
          if (showThinking) const _ThinkingIndicator(),
          if (hasText)
            MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: _markdownStyle(context),
            ),
          if (message.streaming && hasText) const _Caret(),
          if (message.error != null) ...[
            const SizedBox(height: 6),
            _errorBox(message.error!),
          ],
        ],
      ),
    );
  }

  Widget _errorBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final mono = GoogleFonts.robotoMono(
      fontSize: 12.5,
      color: AppColors.brandAccentLight,
    );
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(color: AppColors.textPrimary, height: 1.5, fontSize: 14),
      listBullet:
          const TextStyle(color: AppColors.textPrimary, height: 1.5, fontSize: 14),
      strong: const TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      em: const TextStyle(
          color: AppColors.textPrimary, fontStyle: FontStyle.italic),
      a: const TextStyle(color: AppColors.brandAccent),
      code: mono,
      codeblockDecoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: AppColors.brandAccent, width: 3),
        ),
      ),
      tableBorder: TableBorder.all(color: AppColors.border),
      tableHead: const TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      tableBody: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      h1: const TextStyle(
          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
      h2: const TextStyle(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      h3: const TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          'Pensando…',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: 8,
      height: 14,
      color: AppColors.brandAccent,
    );
  }
}
