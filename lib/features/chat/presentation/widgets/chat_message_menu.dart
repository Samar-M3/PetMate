import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// Actions available from the message long-press menu.
enum ChatMessageAction { reply, copy, deleteForMe, deleteForEveryone, report }

/// Shows a bottom sheet menu for message actions.
Future<ChatMessageAction?> showMessageActionMenu(
  BuildContext context, {
  required bool isMine,
  required bool isTextMessage,
  required bool canDeleteForEveryone,
  required bool isEnded,
}) {
  final actions = <_MenuAction>[];

  // Reply (only in active conversations)
  if (!isEnded) {
    actions.add(_MenuAction(
      action: ChatMessageAction.reply,
      icon: Icons.reply_rounded,
      label: 'Reply',
    ));
  }

  // Copy (text messages only)
  if (isTextMessage) {
    actions.add(_MenuAction(
      action: ChatMessageAction.copy,
      icon: Icons.copy_rounded,
      label: 'Copy',
    ));
  }

  // Delete for me (always available)
  actions.add(_MenuAction(
    action: ChatMessageAction.deleteForMe,
    icon: Icons.delete_outline_rounded,
    label: 'Delete for me',
    isDestructive: true,
  ));

  // Delete for everyone (sender only, within window, active chat)
  if (isMine && canDeleteForEveryone && !isEnded) {
    actions.add(_MenuAction(
      action: ChatMessageAction.deleteForEveryone,
      icon: Icons.delete_forever_rounded,
      label: 'Delete for everyone',
      isDestructive: true,
    ));
  }

  // Report (other person's messages)
  if (!isMine) {
    actions.add(_MenuAction(
      action: ChatMessageAction.report,
      icon: Icons.flag_outlined,
      label: 'Report',
      isDestructive: true,
    ));
  }

  // Haptic feedback
  HapticFeedback.mediumImpact();

  return showModalBottomSheet<ChatMessageAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ...actions.map((a) => ListTile(
                  leading: Icon(
                    a.icon,
                    color: a.isDestructive
                        ? AppColors.error
                        : AppColors.textPrimary,
                    size: 22,
                  ),
                  title: Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 15,
                      color: a.isDestructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, a.action),
                  minTileHeight: 48,
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _MenuAction {
  final ChatMessageAction action;
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _MenuAction({
    required this.action,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });
}

/// Shows a confirmation dialog for delete actions.
Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required bool isForEveryone,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        isForEveryone ? 'Delete for everyone?' : 'Delete for you?',
      ),
      content: Text(
        isForEveryone
            ? 'This message will be deleted for everyone in this chat. Media files will be permanently removed.'
            : 'This message will only be deleted for you. The other person will still see it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
