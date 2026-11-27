import 'package:flutter/material.dart';

import '../../../home/data/models/connection_request_model.dart';

// Design tokens
const _primaryTeal = Color(0xFF0B625B);
const _coralAccent = Color(0xFFE8795B);
const _charcoalText = Color(0xFF26332F);
const _mutedText = Color(0xFF7B8880);
const _softBorder = Color(0xFFE5E8E2);

class IncomingRequestTile extends StatelessWidget {
  final ConnectionRequestModel request;
  final VoidCallback onTap;

  const IncomingRequestTile({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = request.senderPetImageUrl != null &&
        request.senderPetImageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: _coralAccent.withValues(alpha: 0.04),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: _softBorder,
                  backgroundImage: hasImage
                      ? NetworkImage(request.senderPetImageUrl!)
                      : null,
                  child: !hasImage
                      ? const Icon(
                          Icons.pets,
                          color: _primaryTeal,
                          size: 22,
                        )
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      color: _coralAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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
                          '${request.senderPetName} \u2022 ${request.senderUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _charcoalText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryTeal.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Request',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.hasInitialMessage
                        ? '"${request.initialMessage!}"'
                        : 'Wants to connect with ${request.receiverPetName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: request.hasInitialMessage
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: _mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: _mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
