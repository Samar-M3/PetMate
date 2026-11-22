import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// A compact reply bar shown above the message input when replying to a message.
class ChatReplyBar extends StatelessWidget {
  final String senderName;
  final String preview;
  final bool isMediaMessage;
  final VoidCallback onCancel;

  const ChatReplyBar({
    super.key,
    required this.senderName,
    required this.preview,
    this.isMediaMessage = false,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (isMediaMessage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.image_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textMuted,
              onPressed: onCancel,
              tooltip: 'Cancel reply',
            ),
          ),
        ],
      ),
    );
  }
}

/// The quoted reply block shown inside a message bubble.
class QuotedReplyBlock extends StatelessWidget {
  final String senderName;
  final String preview;
  final bool isDeleted;
  final VoidCallback? onTap;

  const QuotedReplyBlock({
    super.key,
    required this.senderName,
    required this.preview,
    this.isDeleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              senderName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDeleted
                    ? AppColors.textMuted
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isDeleted ? 'Message deleted' : preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                color: isDeleted
                    ? AppColors.textMuted
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
