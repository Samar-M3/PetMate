import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../home/data/models/connection_request_model.dart';

class OutgoingRequestTile extends StatelessWidget {
  final OutgoingRequestModel request;
  final VoidCallback onTap;
  final VoidCallback? onAddOrEditIntro;

  const OutgoingRequestTile({
    super.key,
    required this.request,
    required this.onTap,
    this.onAddOrEditIntro,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = request.receiverPetImageUrl != null &&
        request.receiverPetImageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.creamDark,
              backgroundImage:
                  hasImage ? NetworkImage(request.receiverPetImageUrl!) : null,
              child: !hasImage
                  ? const Icon(
                      Icons.pets,
                      color: Color(0xFF0F5C57),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${request.receiverPetName} • ${request.receiverOwnerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: request.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (request.hasInitialMessage)
                    Text(
                      '"${request.initialMessage!}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else if (request.isPending && onAddOrEditIntro != null)
                    GestureDetector(
                      onTap: onAddOrEditIntro,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: Color(0xFF0F5C57),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Add an introductory message',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F5C57),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Liked by ${request.senderPetName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    switch (status) {
      case 'ACCEPTED':
        bg = AppColors.success.withValues(alpha: 0.14);
        fg = AppColors.success;
        label = 'Accepted';
        break;
      case 'DECLINED':
      case 'REJECTED':
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        label = 'Declined';
        break;
      case 'CANCELLED':
        bg = AppColors.textMuted.withValues(alpha: 0.16);
        fg = AppColors.textSecondary;
        label = 'Cancelled';
        break;
      case 'EXPIRED':
        bg = AppColors.textMuted.withValues(alpha: 0.16);
        fg = AppColors.textSecondary;
        label = 'Expired';
        break;
      default:
        bg = const Color(0xFFFF8A65).withValues(alpha: 0.16);
        fg = const Color(0xFFD9643A);
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
