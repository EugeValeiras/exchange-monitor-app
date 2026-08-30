import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/theme/em_tokens.dart';

/// Collapsible card showing a single agent tool call and its result.
class ToolCallTile extends StatefulWidget {
  final ToolUseRecord tool;
  const ToolCallTile({super.key, required this.tool});

  @override
  State<ToolCallTile> createState() => _ToolCallTileState();
}

class _ToolCallTileState extends State<ToolCallTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final pending = tool.result == null;
    final color = tool.isError
        ? EmColors.down
        : pending
            ? EmColors.flow
            : EmColors.up;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: EmColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EmColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (pending)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      tool.isError ? Icons.error_outline : Icons.check_circle_outline,
                      size: 14,
                      color: color,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      tool.name,
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: EmColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: EmColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tool.input != null) ...[
                    _label('Input'),
                    _code(_pretty(tool.input)),
                  ],
                  if (tool.result != null) ...[
                    const SizedBox(height: 8),
                    _label(tool.isError ? 'Error' : 'Resultado'),
                    _code(tool.result!),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: EmColors.textTertiary,
          ),
        ),
      );

  Widget _code(String text) {
    final clipped = text.length > 4000 ? '${text.substring(0, 4000)}…' : text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EmColors.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        clipped,
        style: GoogleFonts.robotoMono(
          fontSize: 11,
          color: EmColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }

  String _pretty(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
