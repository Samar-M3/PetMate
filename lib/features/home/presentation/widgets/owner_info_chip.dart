import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_network_image.dart';

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
              // Owner Avatar with Caching & Fallback
              UserAvatar(
                imageUrl: ownerAvatarUrl,
                radius: 16,
                initials: ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O',
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
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
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
                              fontSize: 10,
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
      ),
    );
  }
}
