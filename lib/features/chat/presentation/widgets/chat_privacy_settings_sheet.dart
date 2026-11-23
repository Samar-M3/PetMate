import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/presence_provider.dart';

Future<void> showChatPrivacySettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ChatPrivacySettingsSheetContent(),
  );
}

class _ChatPrivacySettingsSheetContent extends ConsumerWidget {
  const _ChatPrivacySettingsSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showActivity = ref.watch(showActivityStatusProvider);
    final readReceipts = ref.watch(readReceiptsSettingProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Text(
                  'Chat Privacy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Control what other pet parents can see in real-time chats.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primary,
              title: const Text(
                'Show Activity Status',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Allow matches to see when you are active or recently online. When turned off, you won\'t be able to see the activity status of other users.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
              value: showActivity,
              onChanged: (val) {
                ref.read(showActivityStatusProvider.notifier).toggle(val);
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primary,
              title: const Text(
                'Read Receipts',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Allow matches to see blue double ticks when you have read their messages. When turned off, you won\'t be able to see read receipts from others.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
              value: readReceipts,
              onChanged: (val) {
                ref.read(readReceiptsSettingProvider.notifier).toggle(val);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
