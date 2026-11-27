import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../home/presentation/providers/discovery_provider.dart';
import '../../../profile/data/repositories/public_profile_repository.dart';
import '../../domain/entities/public_pet_profile.dart';

class PetDetailsPage extends ConsumerStatefulWidget {
  final String petId;

  const PetDetailsPage({super.key, required this.petId});

  @override
  ConsumerState<PetDetailsPage> createState() => _PetDetailsPageState();
}

class _PetDetailsPageState extends ConsumerState<PetDetailsPage> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openImageZoom(BuildContext context, String imageUrl, String tag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (ctx, _, _) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Hero(
                  tag: tag,
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    transformationWidth: 1200,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReportDialog(BuildContext context, String petName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Report $petName',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help us keep PetMate safe and authentic. Please select a reason:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...[
              'Inappropriate or offensive photo',
              'Fake or misleading pet profile',
              'Suspected commercial breeder / puppy mill',
              'Harassment or safety concern',
              'Other',
            ].map(
              (reason) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Thank you. Report submitted for review.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String ownerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $ownerName?'),
        content: Text(
          'You will no longer see $ownerName\'s pets in your discovery feed and they will not be able to interact with your pets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$ownerName has been blocked.'),
                  backgroundColor: AppColors.error,
                ),
              );
              if (context.mounted && context.canPop()) {
                context.pop();
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(publicPetProvider(widget.petId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: petAsync.when(
        loading: () => _buildLoadingSkeleton(),
        error: (error, _) => _buildErrorOr404(error),
        data: (pet) => _buildContent(pet),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.terracotta),
            SizedBox(height: 16),
            Text(
              'Loading pet details...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOr404(Object error) {
    final is404 = error is ApiException && error.statusCode == 404;
    final message = is404
        ? 'This pet is no longer available.'
        : 'Unable to load pet details. Please check your network connection.';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (is404 ? AppColors.terracotta : AppColors.error)
                      .withValues(alpha: 0.12),
                ),
                child: Icon(
                  is404 ? Icons.pets_outlined : Icons.cloud_off_rounded,
                  size: 42,
                  color: is404 ? AppColors.terracotta : AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                is404 ? 'Pet Not Available' : 'Something went wrong',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  if (is404) {
                    context.pop();
                  } else {
                    ref.invalidate(publicPetProvider(widget.petId));
                  }
                },
                icon: Icon(
                  is404 ? Icons.arrow_back : Icons.refresh,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  is404 ? 'Go Back' : 'Try Again',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PublicPetProfile pet) {
    final photos = pet.photos.isNotEmpty ? pet.photos : [''];
    final screenWidth = MediaQuery.of(context).size.width;
    final sliderHeight = (screenWidth * 0.78).clamp(260.0, 380.0);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          pet.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textPrimary,
            ),
            onSelected: (val) {
              if (val == 'report') {
                _showReportDialog(context, pet.name);
              } else if (val == 'block') {
                _showBlockDialog(context, pet.owner.displayName);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Report Pet',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 18),
                    SizedBox(width: 10),
                    Text('Block Owner'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. E-commerce style rectangular image slider at top
                _buildEcommerceImageSlider(pet, photos, sliderHeight),

                // 2. Main Pet Info Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Name + Gender Pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              pet.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          _buildGenderBadge(pet.sex),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Breed + Species + Age
                      Text(
                        [
                          if (pet.breed.trim().isNotEmpty) pet.breed.trim(),
                          if (pet.species.trim().isNotEmpty &&
                              pet.species.toLowerCase() !=
                                  pet.breed.toLowerCase())
                            pet.species.trim(),
                          if (pet.ageString.trim().isNotEmpty)
                            pet.ageString.trim(),
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Location + Purpose pill
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: AppColors.terracotta,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pet.area,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (_formatPurpose(pet.purpose) != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.terracotta.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.terracotta.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite_outline_rounded,
                                    size: 13,
                                    color: AppColors.terracotta,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatPurpose(pet.purpose)!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Pet Parent Card
                      _buildOwnerCard(pet),
                      const SizedBox(height: 22),

                      // About Section
                      if (pet.about.trim().isNotEmpty) ...[
                        _buildSectionTitle('About ${pet.name}'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            pet.about.trim(),
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],

                      // Key Details Grid (All entered public attributes)
                      _buildDetailsGrid(pet),

                      // Health & Vaccination Section
                      if (_hasHealthInfo(pet)) ...[
                        _buildHealthSection(pet),
                        const SizedBox(height: 22),
                      ],

                      // Personality & Temperament Traits
                      if (pet.personality.isNotEmpty) ...[
                        _buildSectionTitle('Personality & Temperament'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pet.personality.map((trait) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                trait,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActions(pet),
          ),
        ],
      ),
    );
  }

  Widget _buildEcommerceImageSlider(
    PublicPetProfile pet,
    List<String> photos,
    double sliderHeight,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: sliderHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (idx) {
                      setState(() => _currentPhotoIndex = idx);
                    },
                    itemBuilder: (context, index) {
                      final photoUrl = photos[index];
                      final heroTag = index == 0
                          ? 'pet-photo-${pet.id}'
                          : 'pet-photo-${pet.id}-$index';

                      return GestureDetector(
                        onTap: photoUrl.isNotEmpty
                            ? () => _openImageZoom(context, photoUrl, heroTag)
                            : null,
                        child: Hero(
                          tag: heroTag,
                          child: AppNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.pets,
                            transformationWidth: 1080,
                          ),
                        ),
                      );
                    },
                  ),

                  // Photo counter pill (top-right, e-commerce style)
                  if (photos.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_currentPhotoIndex + 1} / ${photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Tap to zoom pill (bottom-right)
                  if (photos[_currentPhotoIndex].isNotEmpty)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          final url = photos[_currentPhotoIndex];
                          final tag = _currentPhotoIndex == 0
                              ? 'pet-photo-${pet.id}'
                              : 'pet-photo-${pet.id}-$_currentPhotoIndex';
                          _openImageZoom(context, url, tag);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Zoom',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
          ),
        ),

        // Dots & Thumbnail strip below slider when multiple photos exist
        if (photos.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = index == _currentPhotoIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2.2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppNetworkImage(
                        imageUrl: photos[index],
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.pets,
                        transformationWidth: 200,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderBadge(String sex) {
    final isFemale = sex.toLowerCase().contains('female');
    final color = isFemale ? const Color(0xFFE91E63) : const Color(0xFF2196F3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFemale ? Icons.female_rounded : Icons.male_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            sex,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(PublicPetProfile pet) {
    return InkWell(
      onTap: () => context.push('/owner/${pet.owner.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: pet.owner.avatarUrl,
              radius: 22,
              initials: pet.owner.displayName.isNotEmpty
                  ? pet.owner.displayName[0].toUpperCase()
                  : 'O',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pet Parent',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    pet.owner.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Profile',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(PublicPetProfile pet) {
    final items = <_DetailFact>[
      _DetailFact(
        icon: Icons.cake_outlined,
        label: 'Age',
        value: pet.ageString,
      ),
      if (pet.species.trim().isNotEmpty)
        _DetailFact(
          icon: Icons.category_outlined,
          label: 'Species',
          value: pet.species.trim(),
        ),
      if (pet.breed.trim().isNotEmpty)
        _DetailFact(
          icon: Icons.pets_outlined,
          label: 'Breed',
          value: pet.breed.trim(),
        ),
      if (pet.color != null && pet.color!.trim().isNotEmpty)
        _DetailFact(
          icon: Icons.palette_outlined,
          label: 'Color / Coat',
          value: pet.color!.trim(),
        ),
      if (pet.weight != null && pet.weight!.trim().isNotEmpty)
        _DetailFact(
          icon: Icons.monitor_weight_outlined,
          label: 'Weight',
          value: pet.weight!.trim(),
        ),
      if (_formatSize(pet.sizeCategory) != null)
        _DetailFact(
          icon: Icons.straighten_rounded,
          label: 'Size',
          value: _formatSize(pet.sizeCategory)!,
        ),
      if (pet.isNeutered != null)
        _DetailFact(
          icon: Icons.medical_services_outlined,
          label: 'Neutered / Spayed',
          value: pet.isNeutered! ? 'Yes' : 'No',
        ),
      if (pet.hasPedigree == true)
        const _DetailFact(
          icon: Icons.workspace_premium_outlined,
          label: 'Pedigree',
          value: 'Certified',
        ),
      if (pet.hasLitters != null)
        _DetailFact(
          icon: Icons.family_restroom_rounded,
          label: 'Previous Litters',
          value: pet.hasLitters!
              ? (pet.litterCount != null && pet.litterCount! > 0
                  ? 'Yes (${pet.litterCount})'
                  : 'Yes')
              : 'None',
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pet Details'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((item) {
                return SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  bool _hasHealthInfo(PublicPetProfile pet) {
    return (pet.vaccinationStatus != null &&
            pet.vaccinationStatus!.trim().isNotEmpty) ||
        pet.lastVaccinatedDate != null ||
        pet.lastCheckup != null ||
        pet.healthBadges.isNotEmpty;
  }

  Widget _buildHealthSection(PublicPetProfile pet) {
    final formattedVaccinationDate = _formatDate(pet.lastVaccinatedDate);
    final formattedCheckup = _formatCheckup(pet.lastCheckup);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Health & Vaccination'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pet.vaccinationStatus != null &&
                  pet.vaccinationStatus!.trim().isNotEmpty)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            pet.vaccinationStatus!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (formattedVaccinationDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Last vaccinated: $formattedVaccinationDate',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
              if (formattedCheckup != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.health_and_safety_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Last vet checkup: $formattedCheckup',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  String? _formatPurpose(String? purpose) {
    switch (purpose?.toUpperCase()) {
      case 'COMPANION':
        return 'Looking for Playdates';
      case 'MATING':
        return 'Looking for Mating';
      case 'BOTH':
        return 'Playdates & Mating';
      default:
        return null;
    }
  }

  String? _formatSize(String? size) {
    switch (size?.toUpperCase()) {
      case 'SMALL':
        return 'Small';
      case 'MEDIUM':
        return 'Medium';
      case 'LARGE':
        return 'Large';
      case 'GIANT':
        return 'Giant';
      default:
        return size != null && size.trim().isNotEmpty ? size : null;
    }
  }

  String? _formatCheckup(String? checkup) {
    switch (checkup?.toUpperCase()) {
      case 'WITHIN_3_MONTHS':
        return 'Within 3 months';
      case 'WITHIN_6_MONTHS':
        return 'Within 6 months';
      case 'WITHIN_1_YEAR':
        return 'Within 1 year';
      case 'OVER_1_YEAR':
        return 'Over 1 year ago';
      case 'NEVER':
        return 'Not yet';
      default:
        return checkup != null && checkup.trim().isNotEmpty ? checkup : null;
    }
  }

  String? _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return null;
    return DateFormat('MMM d, yyyy').format(parsed.toLocal());
  }

  Widget _buildBottomActions(PublicPetProfile pet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            // Case 1: Relationship is MATCHED -> Open Chat
            if (pet.relationship == 'MATCHED') {
              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  context.pop();
                  context.go('/');
                },
                icon: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                ),
                label: const Text(
                  'Open Chat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            }

            // Case 2: Relationship is REQUEST_SENT -> Disabled button
            if (pet.relationship == 'REQUEST_SENT') {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Request Sent',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Case 3: Relationship is REQUEST_RECEIVED -> Accept / Decline
            if (pet.relationship == 'REQUEST_RECEIVED') {
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: () {
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please respond in the Requests screen',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please accept from the Requests screen',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Accept Playdate',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Case 4: canSwipe is true -> Like & Pass buttons
            if (pet.canSwipe) {
              return Row(
                children: [
                  // Pass Button (X)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      onPressed: () {
                        ref.read(discoveryProvider.notifier).swipeLeft();
                        context.pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      label: const Text(
                        'Pass',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Like Button (Heart)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        ref.read(discoveryProvider.notifier).swipeRight();
                        context.pop();
                      },
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Like',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Default fallback
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _DetailFact {
  final IconData icon;
  final String label;
  final String value;

  const _DetailFact({
    required this.icon,
    required this.label,
    required this.value,
  });
}
