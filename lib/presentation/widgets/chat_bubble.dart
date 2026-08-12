import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';

/// Telegram-style chat bubble.
/// Outgoing = lime, incoming = yellow.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isOutgoing;
  final String? senderName;
  final DateTime? timestamp;
  final bool showAvatar;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutgoing,
    this.senderName,
    this.timestamp,
    this.showAvatar = true,
    this.avatarUrl,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        MediaQuery.of(context).size.width * DesignTokens.bubbleMaxWidth;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space3,
            vertical: DesignTokens.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOutgoing && showAvatar) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: DesignTokens.chipLavender,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: DesignTokens.space2),
              ],
              Flexible(
                child: GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space4,
                      vertical: DesignTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: isOutgoing
                          ? DesignTokens.limeAccent
                          : DesignTokens.yellowAccent,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(DesignTokens.bubbleRadius),
                        topRight: const Radius.circular(DesignTokens.bubbleRadius),
                        bottomLeft: Radius.circular(
                          isOutgoing ? DesignTokens.bubbleRadius : 4,
                        ),
                        bottomRight: Radius.circular(
                          isOutgoing ? 4 : DesignTokens.bubbleRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      text,
                      style: DesignTokens.body(color: DesignTokens.textPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
