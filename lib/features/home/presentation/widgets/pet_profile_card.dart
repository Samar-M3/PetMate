import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/pet_age_formatter.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/entities/discovery_pet.dart';
import 'owner_info_chip.dart';

class PetProfileCard extends StatelessWidget {
  final DiscoveryPet pet;
  final double swipeProgress;
  final VoidCallback? onCardTap;
  final VoidCallback? onOwnerTap;
  final bool enableHero;

  const PetProfileCard({
    super.key,
    required this.pet,
    this.swipeProgress = 0.0,
    this.onCardTap,
    this.onOwnerTap,
    this.enableHero = false,
  });

  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _teal = Color(0xFF2E8B7A);
  static const Color _sageGreen = Color(0xFFE8F0EA);
  static const Color _warmCream = Color(0xFFFAF7F0);
  static const Color _softCoral = Color(0xFFFF8A65);
  static const Color _softGold = Color(0xFFE8C07D);
  static const Color _darkText = Color(0xFF293A37);
  static const Color _scrimBase = Color(0xFF0A1412);

  static const List<Shadow> _textShadows = [
    Shadow(
      color: Color(0x66000000),
      blurRadius: 8,
      offset: Offset(0, 1),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final likeOpacity = swipeProgress.clamp(0.0, 1.0).toDouble();
    final passOpacity = (-swipeProgress).clamp(0.0, 1.0).toDouble();

    final purposeLabel = _formatPurpose(pet.purpose);
    final vaccinationLabel = _formatVaccination(
      pet.vaccinationStatus,
      pet.lastVaccinatedDate,
    );

    return Container(
      decoration: BoxDecoration(
        color: _sageGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1E1B).withValues(alpha: 0.11),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onTap: onCardTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-bleed edge-to-edge pet photograph (75-80% visual focus)
              _buildPetPhoto(pet),

              // 2. Subtle top scrim for owner chip legibility
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 82,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _scrimBase.withValues(alpha: 0.34),
                          _scrimBase.withValues(alpha: 0.08),
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

              // 3. Natural bottom gradient overlay for editorial text legibility
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _scrimBase.withValues(alpha: 0.14),
                          _scrimBase.withValues(alpha: 0.50),
                          _scrimBase.withValues(alpha: 0.84),
                        ],
                        stops: const [0.46, 0.62, 0.78, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Top-left owner overlay
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
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
                  ],
                ),
              ),

              // 5. Swipe feedback stamps (Right = LIKE, Left = PASS)
              if (likeOpacity > 0.04)
                Positioned(
                  top: 76,
                  left: 22,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: Transform.rotate(
                      angle: -0.14,
                      child: _buildSwipeStamp(
                        label: 'LIKE',
                        icon: Icons.favorite_rounded,
                        color: _softCoral,
                      ),
                    ),
                  ),
                ),
              if (passOpacity > 0.04)
                Positioned(
                  top: 76,
                  right: 22,
                  child: Opacity(
                    opacity: passOpacity,
                    child: Transform.rotate(
                      angle: 0.14,
                      child: _buildSwipeStamp(
                        label: 'PASS',
                        icon: Icons.close_rounded,
                        color: _darkText,
                      ),
                    ),
                  ),
                ),

              // 6. Editorial Bumble-inspired bottom info hierarchy (no permanent buttons)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtle highlight badge (e.g. Vaccination status or Purpose)
                    if (vaccinationLabel != null || purposeLabel != null) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (vaccinationLabel != null)
                            _buildStatusHighlightBadge(
                              icon: Icons.verified_user_outlined,
                              label: vaccinationLabel,
                              tint: _teal,
                            ),
                          if (purposeLabel != null)
                            _buildStatusHighlightBadge(
                              icon: Icons.favorite_border_rounded,
                              label: purposeLabel,
                              tint: _softGold,
                              darkText: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Pet Name & Age on one editorial line (Name bold, Age lighter)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: pet.petName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.6,
                              height: 1.12,
                              shadows: _textShadows,
                            ),
                          ),
                          if (formatPetAge(pet.petAge).isNotEmpty)
                            TextSpan(
                              text: ', ${formatPetAge(pet.petAge)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.90),
                                letterSpacing: -0.3,
                                height: 1.12,
                                shadows: _textShadows,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Clean icon + text row: Gender (and optional Neutered)
                    if (pet.petGender.trim().isNotEmpty)
                      _buildAttributeRow(
                        icon: pet.petGender.toLowerCase().contains('female')
                            ? Icons.female_rounded
                            : Icons.male_rounded,
                        text: pet.isNeutered == true
                            ? '${pet.petGender.trim()} · Neutered'
                            : pet.petGender.trim(),
                      ),

                    // Clean icon + text row: Breed (and optional weight)
                    if (pet.petBreed.trim().isNotEmpty ||
                        pet.weightKg != null) ...[
                      const SizedBox(height: 4),
                      _buildAttributeRow(
                        icon: Icons.pets_outlined,
                        text: [
                          if (pet.petBreed.trim().isNotEmpty)
                            pet.petBreed.trim(),
                          if (pet.weightKg != null)
                            '${pet.weightKg!.toStringAsFixed(pet.weightKg! % 1 == 0 ? 0 : 1)} kg',
                        ].join(' · '),
                      ),
                    ],

                    // Understated personality chips (only if entered)
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: Colors.white.withValues(alpha: 0.86),
          shadows: _textShadows,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: -0.1,
              height: 1.25,
              shadows: _textShadows,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHighlightBadge({
    required IconData icon,
    required String label,
    required Color tint,
    bool darkText = false,
  }) {
    final fg = darkText ? _darkText : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: darkText
            ? tint.withValues(alpha: 0.94)
            : tint.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.05,
              ),
            ),
          ),
        ],
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

    if (enableHero) {
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

  Widget _buildSwipeStamp({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  String? _formatPurpose(String? purpose) {
    switch (purpose?.toUpperCase()) {
      case 'COMPANION':
        return 'Playdates';
      case 'MATING':
        return 'Mating';
      case 'BOTH':
        return 'Playdates & Mating';
      default:
        return null;
    }
  }

  String? _formatVaccination(String? status, String? lastVaccinatedDate) {
    if (status == null || status.trim().isEmpty) return null;
    final clean = status.trim();
    final formattedDate = _formatDate(lastVaccinatedDate);
    return formattedDate != null ? '$clean · $formattedDate' : clean;
  }

  String? _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return null;
    return DateFormat('MMM d, yyyy').format(parsed.toLocal());
  }

  Widget _buildPersonalityChip(String trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Text(
        trait,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.94),
        ),
      ),
    );
  }

  Widget _buildMoreTraitsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.8,
        ),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.90),
        ),
      ),
    );
  }
}
