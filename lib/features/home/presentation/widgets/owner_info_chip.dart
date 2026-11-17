import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OwnerInfoChip extends StatelessWidget {
  final String ownerName;
  final String? ownerAge;
  final String ownerLocation;
  final String? ownerAvatarUrl;

  const OwnerInfoChip({
    super.key,
    required this.ownerName,
    this.ownerAge,
    required this.ownerLocation,
    this.ownerAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (ownerAge != null && ownerAge!.isNotEmpty)
        ? '$ownerName, $ownerAge'
        : ownerName;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Owner Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.creamDark,
                backgroundImage: ownerAvatarUrl != null && ownerAvatarUrl!.isNotEmpty
                    ? NetworkImage(ownerAvatarUrl!)
                    : null,
                child: (ownerAvatarUrl == null || ownerAvatarUrl!.isEmpty)
                    ? Text(
                        ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : null,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 11,
                          color: AppColors.terracottaLight,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            ownerLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
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
      ),
    );
  }
}
