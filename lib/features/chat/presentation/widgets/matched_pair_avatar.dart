import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';

class MatchedPairAvatar extends StatelessWidget {
  final String? petImageUrl;
  final String petName;
  final String? ownerImageUrl;
  final String ownerName;
  final double size;

  const MatchedPairAvatar({
    super.key,
    required this.petImageUrl,
    required this.petName,
    required this.ownerImageUrl,
    required this.ownerName,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    // Relative sizes
    final petSize = size * 0.68;
    final ownerSize = size * 0.58;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Matched Pet Avatar (Top-Left)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: petSize,
              height: petSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: AppNetworkImage(
                  imageUrl: petImageUrl,
                  width: petSize,
                  height: petSize,
                  shape: BoxShape.circle,
                  fallbackIcon: Icons.pets,
                ),
              ),
            ),
          ),

          // 2. Pet Owner Avatar (Bottom-Right, overlapping diagonally / slanted)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: ownerSize,
              height: ownerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: ownerImageUrl != null && ownerImageUrl!.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: ownerImageUrl,
                        width: ownerSize,
                        height: ownerSize,
                        shape: BoxShape.circle,
                        fallbackIcon: Icons.person,
                      )
                    : Container(
                        color: AppColors.primary,
                        alignment: Alignment.center,
                        child: Text(
                          ownerName.isNotEmpty
                              ? ownerName[0].toUpperCase()
                              : 'O',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ownerSize * 0.45,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
