import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// Actions available from the message menu.
enum ChatMessageAction {
  reply,
  copy,
  selectMessages,
  deleteForMe,
  deleteForEveryone,
  report,
}

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
    actions.add(
      _MenuAction(
        action: ChatMessageAction.reply,
        icon: Icons.reply_rounded,
        label: 'Reply',
      ),
    );
  }

  // Copy (text messages only)
  if (isTextMessage) {
    actions.add(
      _MenuAction(
        action: ChatMessageAction.copy,
        icon: Icons.copy_rounded,
        label: 'Copy',
      ),
    );
  }

  // Select messages
  actions.add(
    _MenuAction(
      action: ChatMessageAction.selectMessages,
      icon: Icons.check_circle_outline_rounded,
      label: 'Select messages',
    ),
  );

  // Delete for me (always available)
  actions.add(
    _MenuAction(
      action: ChatMessageAction.deleteForMe,
      icon: Icons.delete_outline_rounded,
      label: 'Delete for me',
      isDestructive: true,
    ),
  );

  // Delete for everyone (sender only, within window, active chat)
  if (isMine && canDeleteForEveryone && !isEnded) {
    actions.add(
      _MenuAction(
        action: ChatMessageAction.deleteForEveryone,
        icon: Icons.delete_forever_rounded,
        label: 'Delete for everyone',
        isDestructive: true,
      ),
    );
  }

  // Report (other person's messages)
  if (!isMine) {
    actions.add(
      _MenuAction(
        action: ChatMessageAction.report,
        icon: Icons.flag_outlined,
        label: 'Report',
        isDestructive: true,
      ),
    );
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
            ...actions.map(
              (a) => ListTile(
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
              ),
            ),
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

/// Shows a desktop-style context menu at a specific position.
Future<ChatMessageAction?> showDesktopMessageMenu(
  BuildContext context,
  Offset position, {
  required bool isMine,
  required bool isTextMessage,
  required bool canDeleteForEveryone,
  required bool isEnded,
}) async {
  final items = <PopupMenuEntry<ChatMessageAction>>[
    if (!isEnded)
      const PopupMenuItem(
        value: ChatMessageAction.reply,
        child: Row(
          children: [
            Icon(Icons.reply_rounded, size: 18),
            SizedBox(width: 8),
            Text('Reply'),
          ],
        ),
      ),
    if (isTextMessage)
      const PopupMenuItem(
        value: ChatMessageAction.copy,
        child: Row(
          children: [
            Icon(Icons.copy_rounded, size: 18),
            SizedBox(width: 8),
            Text('Copy'),
          ],
        ),
      ),
    const PopupMenuItem(
      value: ChatMessageAction.selectMessages,
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 18),
          SizedBox(width: 8),
          Text('Select messages'),
        ],
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: ChatMessageAction.deleteForMe,
      child: Row(
        children: [
          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
          SizedBox(width: 8),
          Text('Delete for me', style: TextStyle(color: AppColors.error)),
        ],
      ),
    ),
    if (isMine && canDeleteForEveryone && !isEnded)
      const PopupMenuItem(
        value: ChatMessageAction.deleteForEveryone,
        child: Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              size: 18,
              color: AppColors.error,
            ),
            SizedBox(width: 8),
            Text(
              'Delete for everyone',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
      ),
    if (!isMine)
      const PopupMenuItem(
        value: ChatMessageAction.report,
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
            SizedBox(width: 8),
            Text('Report', style: TextStyle(color: AppColors.error)),
          ],
        ),
      ),
  ];

  return showMenu<ChatMessageAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: items,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required bool isForEveryone,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isForEveryone ? 'Delete for everyone?' : 'Delete for you?'),
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
