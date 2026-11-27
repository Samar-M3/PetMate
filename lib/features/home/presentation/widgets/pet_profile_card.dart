import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../domain/entities/discovery_pet.dart';
import 'owner_info_chip.dart';

class PetProfileCard extends StatefulWidget {
  final DiscoveryPet pet;
  final double swipeProgress;
  final VoidCallback? onCardTap;
  final VoidCallback? onOwnerTap;
  final VoidCallback? onPassTap;
  final VoidCallback? onLikeTap;
  final bool showActionButtons;
  final bool enableHero;

  const PetProfileCard({
    super.key,
    required this.pet,
    this.swipeProgress = 0.0,
    this.onCardTap,
    this.onOwnerTap,
    this.onPassTap,
    this.onLikeTap,
    this.showActionButtons = false,
    this.enableHero = false,
  });

  @override
  State<PetProfileCard> createState() => _PetProfileCardState();
}

class _PetProfileCardState extends State<PetProfileCard> {
  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _sageGreen = Color(0xFFE8F0EA);
  static const Color _warmCream = Color(0xFFFAF7F0);
  static const Color _softCoral = Color(0xFFE16F52);
  static const Color _darkText = Color(0xFF293A37);

  double _passScale = 1.0;
  double _likeScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final likeOpacity = widget.swipeProgress.clamp(0.0, 1.0).toDouble();
    final passOpacity = (-widget.swipeProgress).clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE0E8E2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2926).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // UPPER SECTION: Large pet photograph (~61% of card)
            Expanded(
              flex: 61,
              child: GestureDetector(
                onTap: widget.onCardTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPetPhoto(pet),

                    // Subtle top gradient for chip legibility
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 82,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.36),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Owner chip & Details pill
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
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
                              onAvatarTap: widget.onOwnerTap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onCardTap,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
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
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // LIKE stamp
                    if (likeOpacity > 0.05)
                      Positioned(
                        top: 66,
                        right: 20,
                        child: Opacity(
                          opacity: likeOpacity,
                          child: Transform.rotate(
                            angle: 0.18,
                            child: _buildSwipeStamp(
                              label: 'LIKE',
                              icon: Icons.favorite_rounded,
                              color: _deepTeal,
                            ),
                          ),
                        ),
                      ),

                    // PASS stamp
                    if (passOpacity > 0.05)
                      Positioned(
                        top: 66,
                        left: 20,
                        child: Opacity(
                          opacity: passOpacity,
                          child: Transform.rotate(
                            angle: -0.18,
                            child: _buildSwipeStamp(
                              label: 'PASS',
                              icon: Icons.close_rounded,
                              color: _softCoral,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // LOWER SECTION: Profile details & embedded Pass/Like actions (~39% of card)
            Expanded(
              flex: 39,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scrollable info block prevents overflow on compact devices
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pet name, age & gender badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    pet.petName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _darkText,
                                      letterSpacing: -0.4,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  pet.petAge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF5D6E6A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildGenderBadge(pet.petGender),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // Breed with small paw icon
                            if (pet.petBreed.trim().isNotEmpty)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.pets_rounded,
                                    size: 14,
                                    color: _deepTeal,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      pet.petBreed,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: _deepTeal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // Short biography
                            if (pet.petBio.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                pet.petBio.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: Color(0xFF546460),
                                ),
                              ),
                            ],

                            // Personality chips
                            if (pet.personality.isNotEmpty) ...[
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...pet.personality
                                      .take(3)
                                      .map(_buildPersonalityChip),
                                  if (pet.personality.length > 3)
                                    _buildMoreTraitsChip(
                                      pet.personality.length - 3,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Embedded Pass & Like circular buttons (active card only)
                    if (widget.showActionButtons) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCircularActionButton(
                            scale: _passScale,
                            size: 52,
                            backgroundColor: _warmCream,
                            borderColor: const Color(0xFFE7DCD4),
                            shadowColor: Colors.black.withValues(alpha: 0.08),
                            icon: Icons.close_rounded,
                            iconColor: _softCoral,
                            iconSize: 26,
                            onTapDown: () => setState(() => _passScale = 0.92),
                            onTapCancel: () =>
                                setState(() => _passScale = 1.0),
                            onTapUp: () {
                              setState(() => _passScale = 1.0);
                              widget.onPassTap?.call();
                            },
                          ),
                          const SizedBox(width: 28),
                          _buildCircularActionButton(
                            scale: _likeScale,
                            size: 54,
                            backgroundColor: _softCoral,
                            borderColor: _softCoral,
                            shadowColor: _softCoral.withValues(alpha: 0.30),
                            icon: Icons.favorite_rounded,
                            iconColor: Colors.white,
                            iconSize: 26,
                            onTapDown: () => setState(() => _likeScale = 0.92),
                            onTapCancel: () =>
                                setState(() => _likeScale = 1.0),
                            onTapUp: () {
                              setState(() => _likeScale = 1.0);
                              widget.onLikeTap?.call();
                            },
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
  }

  Widget _buildPetPhoto(DiscoveryPet pet) {
    final hasValidUrl =
        pet.petImageUrl.trim().isNotEmpty &&
        pet.petImageUrl.trim().startsWith('http');

    final Widget imageContent = hasValidUrl
        ? AppNetworkImage(
            imageUrl: pet.petImageUrl.trim(),
            fit: BoxFit.cover,
            fallbackIcon: Icons.pets_rounded,
            backgroundColor: _sageGreen,
            transformationWidth: 1080,
          )
        : _buildNoPhotoFallback(pet.petName);

    if (widget.enableHero) {
      return Hero(
        tag: 'pet-photo-${pet.id}',
        child: imageContent,
      );
    }
    return imageContent;
  }

  Widget _buildNoPhotoFallback(String petName) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_sageGreen, _warmCream],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _deepTeal.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 34,
                color: _deepTeal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              petName.isNotEmpty ? petName : 'Pet Photo',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderBadge(String gender) {
    final isFemale = gender.toLowerCase().contains('female');
    final bgColor = isFemale ? const Color(0xFFFBECE8) : _sageGreen;
    final fgColor = isFemale ? _softCoral : _deepTeal;
    final icon = isFemale ? Icons.female_rounded : Icons.male_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fgColor),
          const SizedBox(width: 2),
          Text(
            gender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeStamp({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityChip(String trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _sageGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        trait,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _deepTeal,
        ),
      ),
    );
  }

  Widget _buildMoreTraitsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _warmCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE4DE)),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _darkText,
        ),
      ),
    );
  }

  Widget _buildCircularActionButton({
    required double scale,
    required double size,
    required Color backgroundColor,
    required Color borderColor,
    required Color shadowColor,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required VoidCallback onTapDown,
    required VoidCallback onTapCancel,
    required VoidCallback onTapUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapCancel: onTapCancel,
      onTapUp: (_) => onTapUp(),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
