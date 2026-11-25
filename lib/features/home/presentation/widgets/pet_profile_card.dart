import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/entities/discovery_pet.dart';
import 'owner_info_chip.dart';

class PetProfileCard extends StatelessWidget {
  final DiscoveryPet pet;
  final double swipeProgress;
  final VoidCallback? onCardTap;
  final VoidCallback? onOwnerTap;

  const PetProfileCard({
    super.key,
    required this.pet,
    this.swipeProgress = 0.0,
    this.onCardTap,
    this.onOwnerTap,
  });

  @override
  Widget build(BuildContext context) {
    final likeOpacity = swipeProgress.clamp(0.0, 1.0).toDouble();
    final passOpacity = (-swipeProgress).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.7;

        // Bottom panel content area height
        final bottomPanelHeight = cardHeight * 0.44;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Pet photo
                Hero(
                  tag: 'pet-photo-${pet.id}',
                  child: AppNetworkImage(
                    imageUrl: pet.petImageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.pets,
                    transformationWidth: 1080,
                  ),
                ),

                // Top gradient scrim for status/owner chip legibility
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 96,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Bottom gradient scrim for text content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: bottomPanelHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.40, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Owner information and details button
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: OwnerInfoChip(
                          ownerName: pet.ownerName,
                          ownerAge: pet.ownerAge,
                          ownerLocation: pet.ownerLocation,
                          ownerAvatarUrl: pet.ownerAvatarUrl,
                          onAvatarTap: onOwnerTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onCardTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // LIKE stamp (crisp, no neon glow)
                if (likeOpacity > 0.05)
                  Positioned(
                    top: 60,
                    right: 20,
                    child: Opacity(
                      opacity: likeOpacity,
                      child: Transform.rotate(
                        angle: 0.20,
                        child: _buildSwipeStamp(
                          label: 'LIKE',
                          icon: Icons.favorite_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),

                // PASS stamp (crisp, no neon glow)
                if (passOpacity > 0.05)
                  Positioned(
                    top: 60,
                    left: 20,
                    child: Opacity(
                      opacity: passOpacity,
                      child: Transform.rotate(
                        angle: -0.20,
                        child: _buildSwipeStamp(
                          label: 'PASS',
                          icon: Icons.close_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),

                // Bounded pet information
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 14,
                  height: bottomPanelHeight - 14,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pet name, age, and gender
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                pet.petName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                pet.petAge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                pet.petGender,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Breed
                        Row(
                          children: [
                            const Icon(
                              Icons.pets,
                              size: 13,
                              color: AppColors.primaryLight,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pet.petBreed,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.cream,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Bio
                        if (pet.petBio.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            pet.petBio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],

                        // Personality tags (quiet, non-distracting translucent pills)
                        if (pet.personality.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ...pet.personality
                                  .take(4)
                                  .map(_buildPersonalityChip),
                              if (pet.personality.length > 4)
                                _buildMoreTraitsChip(
                                  pet.personality.length - 4,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeStamp({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityChip(String trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        trait,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMoreTraitsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
