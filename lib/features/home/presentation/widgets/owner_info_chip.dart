import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';

class OwnerInfoChip extends StatelessWidget {
  final String ownerName;
  final String? ownerAge;
  final String ownerLocation;
  final String? ownerAvatarUrl;
  final VoidCallback? onAvatarTap;

  const OwnerInfoChip({
    super.key,
    required this.ownerName,
    this.ownerAge,
    required this.ownerLocation,
    this.ownerAvatarUrl,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (ownerAge != null && ownerAge!.isNotEmpty)
        ? '$ownerName, $ownerAge'
        : ownerName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAvatarTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1614).withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Owner Avatar with Caching & Fallback
            UserAvatar(
              imageUrl: ownerAvatarUrl,
              radius: 14,
              initials: ownerName.isNotEmpty
                  ? ownerName[0].toUpperCase()
                  : 'O',
            ),
            const SizedBox(width: 8),

            // Owner Details
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          ownerLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
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
