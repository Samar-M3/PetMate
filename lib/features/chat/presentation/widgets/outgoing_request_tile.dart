import 'package:flutter/material.dart';

import '../../../home/data/models/connection_request_model.dart';

// Design tokens
const _primaryTeal = Color(0xFF0B625B);
const _coralAccent = Color(0xFFE8795B);
const _charcoalText = Color(0xFF26332F);
const _mutedText = Color(0xFF7B8880);
const _softBorder = Color(0xFFE5E8E2);

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: _softBorder,
              backgroundImage:
                  hasImage ? NetworkImage(request.receiverPetImageUrl!) : null,
              child: !hasImage
                  ? const Icon(
                      Icons.pets,
                      color: _primaryTeal,
                      size: 22,
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
                          '${request.receiverPetName} \u2022 ${request.receiverOwnerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _charcoalText,
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
                        color: _mutedText,
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
                            size: 15,
                            color: _primaryTeal,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Add an introductory message',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _primaryTeal,
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
                        color: _mutedText,
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
        bg = const Color(0xFF2E7D5F).withValues(alpha: 0.12);
        fg = const Color(0xFF2E7D5F);
        label = 'Accepted';
        break;
      case 'DECLINED':
      case 'REJECTED':
        bg = Colors.red.withValues(alpha: 0.10);
        fg = Colors.red;
        label = 'Declined';
        break;
      case 'CANCELLED':
        bg = _mutedText.withValues(alpha: 0.12);
        fg = _mutedText;
        label = 'Cancelled';
        break;
      case 'EXPIRED':
        bg = _mutedText.withValues(alpha: 0.12);
        fg = _mutedText;
        label = 'Expired';
        break;
      default:
        bg = _coralAccent.withValues(alpha: 0.12);
        fg = _coralAccent;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
