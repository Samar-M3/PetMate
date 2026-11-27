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
  static const Color _coral = Color(0xFFFF8A65);
  static const Color _darkText = Color(0xFF293A37);
  static const Color _scrimBase = Color(0xFF0B1614);

  static const List<Shadow> _textShadows = [
    Shadow(
      color: Color(0x8A000000),
      blurRadius: 10,
      offset: Offset(0, 1.5),
    ),
  ];

  double _passScale = 1.0;
  double _likeScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final likeOpacity = widget.swipeProgress.clamp(0.0, 1.0).toDouble();
    final passOpacity = (-widget.swipeProgress).clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: _sageGreen,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1E1B).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: GestureDetector(
          onTap: widget.onCardTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-bleed pet photograph
              _buildPetPhoto(pet),

              // 2. Subtle top scrim for owner chip & Details button legibility
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 104,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _scrimBase.withValues(alpha: 0.44),
                          _scrimBase.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Smooth bottom gradient blending naturally into the image
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _scrimBase.withValues(alpha: 0.08),
                          _scrimBase.withValues(alpha: 0.36),
                          _scrimBase.withValues(alpha: 0.70),
                          _scrimBase.withValues(alpha: 0.89),
                        ],
                        stops: const [0.36, 0.50, 0.66, 0.83, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Top-left owner overlay & top-right subtle Details pill
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
                        onAvatarTap: widget.onOwnerTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildDetailsPill(),
                  ],
                ),
              ),

              // 5. Swipe feedback stamps
              if (likeOpacity > 0.05)
                Positioned(
                  top: 76,
                  right: 20,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: Transform.rotate(
                      angle: 0.16,
                      child: _buildSwipeStamp(
                        label: 'LIKE',
                        icon: Icons.favorite_rounded,
                        color: _coral,
                      ),
                    ),
                  ),
                ),
              if (passOpacity > 0.05)
                Positioned(
                  top: 76,
                  left: 20,
                  child: Opacity(
                    opacity: passOpacity,
                    child: Transform.rotate(
                      angle: -0.16,
                      child: _buildSwipeStamp(
                        label: 'PASS',
                        icon: Icons.close_rounded,
                        color: const Color(0xFF394A46),
                      ),
                    ),
                  ),
                ),

              // 6. Lower photo info overlay & Pass/Like action buttons
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name, age & gender
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            pet.petName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.12,
                              shadows: _textShadows,
                            ),
                          ),
                        ),
                        if (pet.petAge.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            pet.petAge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w500,
                              color: _warmCream.withValues(alpha: 0.92),
                              shadows: _textShadows,
                            ),
                          ),
                        ],
                        if (pet.petGender.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildGenderPill(pet.petGender),
                        ],
                      ],
                    ),

                    // Breed with small paw icon
                    if (pet.petBreed.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.pets_rounded,
                            size: 14,
                            color: _warmCream.withValues(alpha: 0.92),
                            shadows: _textShadows,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pet.petBreed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _warmCream.withValues(alpha: 0.94),
                                letterSpacing: -0.1,
                                shadows: _textShadows,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Personality tags
                    if (pet.personality.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...pet.personality
                              .take(3)
                              .map(_buildPersonalityChip),
                          if (pet.personality.length > 3)
                            _buildMoreTraitsChip(pet.personality.length - 3),
                        ],
                      ),
                    ],

                    // Two swipe action buttons: Pass (X) & Like (Heart)
                    if (widget.showActionButtons) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCircularActionButton(
                            scale: _passScale,
                            size: 56,
                            backgroundColor: _warmCream,
                            borderColor: Colors.white.withValues(alpha: 0.85),
                            shadowColor: Colors.black.withValues(alpha: 0.22),
                            icon: Icons.close_rounded,
                            iconColor: const Color(0xFF394A46),
                            iconSize: 26,
                            onTapDown: () => setState(() => _passScale = 0.90),
                            onTapCancel: () =>
                                setState(() => _passScale = 1.0),
                            onTapUp: () {
                              setState(() => _passScale = 1.0);
                              widget.onPassTap?.call();
                            },
                          ),
                          const SizedBox(width: 30),
                          _buildCircularActionButton(
                            scale: _likeScale,
                            size: 60,
                            backgroundColor: _coral,
                            borderColor:
                                const Color(0xFFFFAD93).withValues(alpha: 0.65),
                            shadowColor: _coral.withValues(alpha: 0.36),
                            icon: Icons.favorite_rounded,
                            iconColor: Colors.white,
                            iconSize: 28,
                            onTapDown: () => setState(() => _likeScale = 0.90),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onCardTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _scrimBase.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(18),
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
              SizedBox(width: 5),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _deepTeal.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 36,
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

  Widget _buildGenderPill(String gender) {
    final isFemale = gender.toLowerCase().contains('female');
    final icon = isFemale ? Icons.female_rounded : Icons.male_rounded;
    final tint = isFemale
        ? _coral.withValues(alpha: 0.24)
        : _deepTeal.withValues(alpha: 0.38);
    final borderTint = isFemale
        ? _coral.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.26);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderTint, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            gender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Text(
        trait,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: _warmCream,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildMoreTraitsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _deepTeal.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: _warmCream,
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
        duration: const Duration(milliseconds: 120),
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
                blurRadius: 16,
                offset: const Offset(0, 6),
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
