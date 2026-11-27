import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/breeds.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../onboarding/data/onboarding_models.dart';
import '../../data/registration_service.dart';
import '../providers/registration_provider.dart';

class RegStep2PetProfile extends ConsumerStatefulWidget {
  const RegStep2PetProfile({super.key});

  @override
  ConsumerState<RegStep2PetProfile> createState() => RegStep2PetProfileState();
}

class RegStep2PetProfileState extends ConsumerState<RegStep2PetProfile> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _speciesOtherController;
  late TextEditingController _breedOtherController;
  late TextEditingController _yearsController;
  late TextEditingController _monthsController;

  String _selectedSpecies = 'Dog';
  String? _selectedBreed;
  String? _selectedGender; // 'MALE' or 'FEMALE'

  List<PetPhotoItem> _photos = [];
  bool _isUploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final pet = ref.read(registrationProvider).pet;

    _nameController = TextEditingController(text: pet?.name ?? '');
    _speciesOtherController =
        TextEditingController(text: pet?.speciesOther ?? '');
    _breedOtherController = TextEditingController();
    _yearsController = TextEditingController(
      text: pet != null && pet.ageYears > 0 ? pet.ageYears.toString() : '',
    );
    _monthsController = TextEditingController(
      text: (pet?.ageMonths ?? 0).toString(),
    );

    if (pet != null && pet.species.isNotEmpty) {
      _selectedSpecies = _capitalize(pet.species);
      _selectedBreed = pet.breed;
      _selectedGender = pet.gender.toUpperCase();
      _photos = List.from(pet.photos);
    } else {
      _selectedBreed = PetSpeciesConstants.breedsForSpecies(_selectedSpecies).first;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesOtherController.dispose();
    _breedOtherController.dispose();
    _yearsController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  List<String> get _currentBreedList {
    return PetSpeciesConstants.breedsForSpecies(_selectedSpecies);
  }

  Future<void> _pickAndUploadPhoto() async {
    final remainingSlots = 6 - _photos.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos allowed.')),
      );
      return;
    }

    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (pickedFiles.isEmpty) return;

      final selectedFiles = pickedFiles.take(remainingSlots).toList();
      if (pickedFiles.length > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remainingSlots more ${remainingSlots == 1 ? 'photo' : 'photos'} can be added (max 6).',
            ),
          ),
        );
      }

      setState(() => _isUploadingPhoto = true);

      final service = ref.read(registrationServiceProvider);
      final uploadedItems = <PetPhotoItem>[];
      var skippedOversized = 0;

      for (final picked in selectedFiles) {
        final bytes = await picked.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          skippedOversized++;
          continue;
        }

        final asset = await service.uploadImage(
          bytes: bytes,
          filename: picked.name.isNotEmpty ? picked.name : 'pet_photo.jpg',
          folder: 'pets',
        );

        final nextIndex = _photos.length + uploadedItems.length;
        uploadedItems.add(PetPhotoItem(
          url: asset.url,
          publicId: asset.publicId,
          position: nextIndex,
          isPrimary: nextIndex == 0,
        ));
      }

      if (mounted) {
        setState(() {
          _photos.addAll(uploadedItems);
          for (int i = 0; i < _photos.length; i++) {
            _photos[i] = _photos[i].copyWith(
              position: i,
              isPrimary: i == 0,
            );
          }
          _isUploadingPhoto = false;
        });

        if (skippedOversized > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$skippedOversized ${skippedOversized == 1 ? 'image was' : 'images were'} skipped (must be under 5 MB).',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      for (int i = 0; i < _photos.length; i++) {
        _photos[i] = _photos[i].copyWith(
          position: i,
          isPrimary: i == 0,
        );
      }
    });
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      final item = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, item);
      for (int i = 0; i < _photos.length; i++) {
        _photos[i] = _photos[i].copyWith(
          position: i,
          isPrimary: i == 0,
        );
      }
    });
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pet gender (Male or Female).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final years = int.tryParse(_yearsController.text.trim()) ?? 0;
    final months = int.tryParse(_monthsController.text.trim()) ?? 0;
    if (_monthsController.text.trim().isEmpty) {
      _monthsController.text = '0';
    }

    if (years == 0 && months == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Age must be greater than 0 months.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 1 photo of your pet.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String finalBreed = _selectedBreed ?? 'Mixed';
    if (_selectedBreed == 'Other' && _breedOtherController.text.trim().isNotEmpty) {
      finalBreed = _breedOtherController.text.trim();
    }

    await ref.read(registrationProvider.notifier).submitStep2(
          name: _nameController.text.trim(),
          species: _selectedSpecies,
          speciesOther: _selectedSpecies == 'Other'
              ? _speciesOtherController.text.trim()
              : null,
          breed: finalBreed,
          gender: _selectedGender!,
          ageYears: years,
          ageMonths: months,
          photos: _photos,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pet Name
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Pet Name *',
              hintText: 'e.g. Bruno',
              prefixIcon: Icon(Icons.pets, color: AppColors.primary),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please enter your pet\'s name' : null,
          ),
          const SizedBox(height: 16),

          // Species Dropdown
          DropdownButtonFormField<String>(
            value: _selectedSpecies,
            decoration: const InputDecoration(
              labelText: 'Species *',
              prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary),
            ),
            items: PetSpeciesConstants.allSpecies
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedSpecies = val;
                  final breeds = PetSpeciesConstants.breedsForSpecies(val);
                  _selectedBreed = breeds.isNotEmpty ? breeds.first : 'Mixed';
                });
              }
            },
          ),
          const SizedBox(height: 16),

          if (_selectedSpecies == 'Other') ...[
            TextFormField(
              controller: _speciesOtherController,
              decoration: const InputDecoration(
                labelText: 'Specify Species *',
                hintText: 'e.g. Turtle, Guinea Pig',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please specify species' : null,
            ),
            const SizedBox(height: 16),
          ],

          // Breed Dropdown
          if (_currentBreedList.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _currentBreedList.contains(_selectedBreed)
                  ? _selectedBreed
                  : _currentBreedList.first,
              decoration: const InputDecoration(
                labelText: 'Breed *',
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
              ),
              items: _currentBreedList
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedBreed = val);
              },
            ),
          const SizedBox(height: 16),

          if (_selectedBreed == 'Other') ...[
            TextFormField(
              controller: _breedOtherController,
              decoration: const InputDecoration(
                labelText: 'Specify Breed *',
                hintText: 'e.g. Golden Retriever mix',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please specify breed' : null,
            ),
            const SizedBox(height: 16),
          ],

          // Gender Selection (Cards)
          const Text(
            'Gender * (Essential for mating)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  title: 'Male',
                  icon: Icons.male_rounded,
                  selectedIconColor: Colors.lightBlue,
                  isSelected: _selectedGender == 'MALE',
                  onTap: () => setState(() => _selectedGender = 'MALE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  title: 'Female',
                  icon: Icons.female_rounded,
                  selectedIconColor: Colors.pink.shade300,
                  isSelected: _selectedGender == 'FEMALE',
                  onTap: () => setState(() => _selectedGender = 'FEMALE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Age Inputs (Years & Months)
          const Text(
            'Age *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _yearsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Years',
                    hintText: '0–30',
                  ),
                  validator: (v) {
                    final num = int.tryParse(v?.trim() ?? '');
                    if (num != null && num > 30) return 'Max 30 yrs';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _monthsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Months',
                    hintText: '0–11',
                  ),
                  validator: (v) {
                    final num = int.tryParse(v?.trim() ?? '');
                    if (num != null && num > 11) return '0–11 only';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Photos Grid (1–6)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pet Photos * (1 to 6)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_photos.length}/6 photos',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'The first photo is your pet\'s primary cover photo. Hold and drag to reorder.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _photos.length < 6 ? _photos.length + 1 : _photos.length,
            itemBuilder: (context, index) {
              if (index == _photos.length) {
                // Add photo tile
                return InkWell(
                  onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryLight,
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: _isUploadingPhoto
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                              SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }

              final photo = _photos[index];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final tileSize = constraints.maxWidth;
                  return DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data != index,
                    onAcceptWithDetails: (details) =>
                        _reorderPhotos(details.data, index),
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      final tileContent = Container(
                        decoration: isHovered
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2.5,
                                ),
                              )
                            : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AppNetworkImage(
                                imageUrl: photo.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                right: 4,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark
                                        .withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Primary',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      return LongPressDraggable<int>(
                        data: index,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.transparent,
                          child: SizedBox(
                            width: tileSize * 1.05,
                            height: tileSize * 1.05,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AppNetworkImage(
                                imageUrl: photo.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 1.5,
                            ),
                          ),
                          child: Opacity(
                            opacity: 0.3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: AppNetworkImage(
                                imageUrl: photo.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        child: tileContent,
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color selectedIconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.title,
    required this.icon,
    required this.selectedIconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedIconColor : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
