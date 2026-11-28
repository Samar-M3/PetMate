import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/breeds.dart';
import '../../../../core/services/pet_image_validation_service.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/onboarding_models.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_scaffold.dart';

class Step2PetProfile extends ConsumerStatefulWidget {
  const Step2PetProfile({super.key});

  @override
  ConsumerState<Step2PetProfile> createState() => _Step2PetProfileState();
}

class _Step2PetProfileState extends ConsumerState<Step2PetProfile> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesOtherController = TextEditingController();
  final _breedTextController = TextEditingController();
  final _yearsController = TextEditingController(text: '1');
  final _monthsController = TextEditingController(text: '0');

  String _species = 'DOG';
  String? _selectedBreed;
  String? _gender;
  final List<PetPhotoItem> _photos = [];
  bool _isUploadingPhoto = false;
  bool _isValidatingPhoto = false;
  PetImageValidationResult? _validationResult;
  String? _validatedForAnimalType;
  final Map<String, ({File? file, Uint8List? bytes})> _localPhotoCache = {};
  String? _photoError;
  String? _ageError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    if (_initialized) return;
    _initialized = true;
    final pet = ref.read(onboardingProvider).pet;
    if (pet != null) {
      _nameController.text = pet.name;
      _species = pet.species;
      _speciesOtherController.text = pet.speciesOther ?? '';
      final breeds = PetSpeciesConstants.breedsFor(_species);
      if (breeds.isNotEmpty && breeds.contains(pet.breed)) {
        _selectedBreed = pet.breed;
      } else if (breeds.isNotEmpty) {
        _selectedBreed = 'Other';
        _breedTextController.text = pet.breed;
      } else {
        _breedTextController.text = pet.breed;
      }
      _gender = pet.gender;
      _yearsController.text = pet.ageYears.toString();
      _monthsController.text = pet.ageMonths.toString();
      _photos
        ..clear()
        ..addAll(pet.photos);
    } else {
      final breeds = PetSpeciesConstants.breedsFor(_species);
      if (breeds.isNotEmpty) {
        _selectedBreed = breeds.first;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesOtherController.dispose();
    _breedTextController.dispose();
    _yearsController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  String get _effectiveAnimalType {
    if (_species.toUpperCase() == 'OTHER') {
      final custom = _speciesOtherController.text.trim();
      return custom.isNotEmpty ? custom : 'Other';
    }
    return _species;
  }

  Future<void> _revalidateExistingPhotosForSpecies() async {
    final targetAnimal = _effectiveAnimalType;
    if (_photos.isEmpty) {
      setState(() {
        _validationResult = null;
        _validatedForAnimalType = null;
      });
      return;
    }

    setState(() {
      _isValidatingPhoto = true;
      _validationResult = null;
      _photoError = null;
    });

    final validator = ref.read(petImageValidationServiceProvider);
    final kept = <PetPhotoItem>[];
    PetImageValidationResult? lastFailure;
    PetImageValidationResult? lastSuccess;
    var removedUncached = 0;

    for (final photo in _photos) {
      final cached = _localPhotoCache[photo.url];
      if (cached == null) {
        removedUncached++;
        continue;
      }
      final result = await validator.validatePetImage(
        imageFile: cached.file,
        imageBytes: cached.bytes,
        selectedAnimalType: targetAnimal,
      );
      if (!mounted) return;
      if (result.isValid) {
        kept.add(photo);
        lastSuccess = result;
      } else {
        _localPhotoCache.remove(photo.url);
        lastFailure = result;
      }
    }

    _photos
      ..clear()
      ..addAll(kept);
    _reindexPhotos();

    setState(() {
      _isValidatingPhoto = false;
      _validationResult = lastFailure ?? lastSuccess;
      _validatedForAnimalType = kept.isNotEmpty ? targetAnimal : null;
      if (removedUncached > 0 && lastFailure == null) {
        _photoError = 'Please re-upload your pet photo(s) for the newly selected animal type.';
      }
    });
  }

  void _onSpeciesChanged(String? nextSpecies) {
    if (nextSpecies == null || nextSpecies == _species) return;
    setState(() {
      _species = nextSpecies;
      _selectedBreed = null; // Reset breed when species changes
      _breedTextController.clear();
      final breeds = PetSpeciesConstants.breedsFor(_species);
      if (breeds.isNotEmpty) {
        _selectedBreed = breeds.first;
      }
    });
    _revalidateExistingPhotosForSpecies();
  }

  Future<void> _showAddPhotoSheet() async {
    if (_photos.length >= 6) {
      setState(() => _photoError = 'Maximum 6 photos allowed.');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80, // Client-side compression
      );
      if (picked == null) return;

      final ext = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        setState(() {
          _photoError = 'Invalid file type. Only JPG, PNG, and WebP are allowed.';
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _photoError = 'Image exceeds 5 MB limit after compression.';
        });
        return;
      }

      final file = kIsWeb ? null : File(picked.path);
      final targetAnimal = _effectiveAnimalType;

      setState(() {
        _isValidatingPhoto = true;
        _validationResult = null;
        _photoError = null;
      });

      final validation = await ref
          .read(petImageValidationServiceProvider)
          .validatePetImage(
            imageFile: file,
            imageBytes: bytes,
            selectedAnimalType: targetAnimal,
          );

      if (!mounted) return;

      if (!validation.isValid) {
        setState(() {
          _isValidatingPhoto = false;
          _validationResult = validation;
          _photoError = validation.message;
        });
        return;
      }

      setState(() {
        _isValidatingPhoto = false;
        _isUploadingPhoto = true;
        _validationResult = validation;
      });

      final asset = await ref.read(onboardingProvider.notifier).uploadPublicImage(
            file: file,
            bytes: bytes,
            filename: picked.name,
            folder: 'pets',
          );

      _localPhotoCache[asset.url] = (file: file, bytes: bytes);
      setState(() {
        final pos = _photos.length;
        _photos.add(
          PetPhotoItem(
            url: asset.url,
            publicId: asset.publicId,
            position: pos,
            isPrimary: pos == 0,
          ),
        );
        _validatedForAnimalType = targetAnimal;
        _isUploadingPhoto = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
        _photoError = 'Upload failed. Please check your connection and try again.';
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _reindexPhotos();
    });
  }

  void _movePhotoLeft(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _photos.removeAt(index);
      _photos.insert(index - 1, item);
      _reindexPhotos();
    });
  }

  void _reindexPhotos() {
    for (var i = 0; i < _photos.length; i++) {
      _photos[i] = PetPhotoItem(
        url: _photos[i].url,
        publicId: _photos[i].publicId,
        position: i,
        isPrimary: i == 0,
      );
    }
  }

  Future<void> _onNext() async {
    setState(() {
      _ageError = null;
      _photoError = null;
    });

    final formValid = _formKey.currentState!.validate();
    final years = int.tryParse(_yearsController.text.trim()) ?? 0;
    final months = int.tryParse(_monthsController.text.trim()) ?? 0;

    if (years == 0 && months == 0) {
      setState(() {
        _ageError = 'At least years or months must be greater than 0.';
      });
      return;
    }

    if (_isValidatingPhoto) {
      setState(() {
        _photoError = 'Please wait while we verify your pet\'s photo.';
      });
      return;
    }

    if (_photos.isEmpty) {
      setState(() {
        _photoError = _validationResult != null && !_validationResult!.isValid
            ? _validationResult!.message
            : 'Please upload at least 1 photo of your pet.';
      });
      return;
    }

    if (_validationResult != null &&
        !_validationResult!.isValid &&
        _validatedForAnimalType != _effectiveAnimalType) {
      setState(() {
        _photoError = _validationResult!.message;
      });
      return;
    }

    if (!formValid || _isUploadingPhoto) return;

    final breeds = PetSpeciesConstants.breedsFor(_species);
    final resolvedBreed = (breeds.isEmpty || _selectedBreed == 'Other')
        ? _breedTextController.text.trim()
        : _selectedBreed!;

    await ref.read(onboardingProvider.notifier).saveStep2(
          name: _nameController.text.trim(),
          species: _species,
          speciesOther:
              _species == 'OTHER' ? _speciesOtherController.text.trim() : null,
          breed: resolvedBreed,
          gender: _gender!,
          ageYears: years,
          ageMonths: months,
          photos: _photos,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final breeds = PetSpeciesConstants.breedsFor(_species);
    final showFreeTextBreed = breeds.isEmpty || _selectedBreed == 'Other';

    return OnboardingScaffold(
      step: 2,
      title: 'About your pet',
      subtitle: 'All fields below are required to create your pet profile.',
      isSaving: state.isSaving || _isUploadingPhoto,
      errorMessage: state.errorMessage,
      onBack: () => ref.read(onboardingProvider.notifier).goBack(),
      onRetry: _onNext,
      onNext: _onNext,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pet Name
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Pet name *',
                hintText: 'e.g. Bruno',
                prefixIcon: const Icon(Icons.pets_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Pet name is required' : null,
            ),
            const SizedBox(height: 16),

            // Species Dropdown
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: InputDecoration(
                labelText: 'Species *',
                prefixIcon: const Icon(Icons.category_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: PetSpeciesConstants.speciesOptions
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['value'],
                      child: Text(s['label']!),
                    ),
                  )
                  .toList(),
              onChanged: _onSpeciesChanged,
            ),
            if (_species == 'OTHER') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _speciesOtherController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Specify species *',
                  hintText: 'e.g. Guinea Pig, Turtle',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) => _species == 'OTHER' &&
                        (v == null || v.trim().isEmpty)
                    ? 'Please enter the species name'
                    : null,
              ),
            ],
            const SizedBox(height: 16),

            // Breed Dropdown (or free text if Other species)
            if (breeds.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedBreed,
                decoration: InputDecoration(
                  labelText: 'Breed *',
                  prefixIcon: const Icon(Icons.auto_awesome_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: breeds
                    .map(
                      (b) => DropdownMenuItem<String>(
                        value: b,
                        child: Text(b),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedBreed = v),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please select a breed' : null,
              ),
            ],
            if (showFreeTextBreed) ...[
              if (breeds.isNotEmpty) const SizedBox(height: 12),
              TextFormField(
                controller: _breedTextController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText:
                      breeds.isEmpty ? 'Breed *' : 'Enter breed name *',
                  hintText: 'e.g. Himalayan / Mixed',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) =>
                    showFreeTextBreed && (v == null || v.trim().isEmpty)
                        ? 'Breed is required'
                        : null,
              ),
            ],
            const SizedBox(height: 16),

            // Gender (Male or Female)
            FormField<String>(
              initialValue: _gender,
              validator: (_) =>
                  _gender == null ? 'Please select Male or Female' : null,
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gender *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _GenderCard(
                            label: 'Male',
                            icon: Icons.male_rounded,
                            selected: _gender == 'MALE',
                            onTap: () {
                              setState(() => _gender = 'MALE');
                              field.didChange('MALE');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GenderCard(
                            label: 'Female',
                            icon: Icons.female_rounded,
                            selected: _gender == 'FEMALE',
                            onTap: () {
                              setState(() => _gender = 'FEMALE');
                              field.didChange('FEMALE');
                            },
                          ),
                        ),
                      ],
                    ),
                    if (field.hasError) ...[
                      const SizedBox(height: 6),
                      Text(
                        field.errorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Age: Years (0..30) and Months (0..11)
            const Text(
              'Age *',
              style: TextStyle(
                fontSize: 13,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Years (0–30)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '') ?? -1;
                      if (n < 0 || n > 30) return '0 to 30';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _monthsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Months (0–11)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '') ?? -1;
                      if (n < 0 || n > 11) return '0 to 11';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (_ageError != null) ...[
              const SizedBox(height: 6),
              Text(
                _ageError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),

            // Photos Grid (1 to 6)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pet Photos * (1–6)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_photos.length}/6',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'First photo is the main profile photo. Tap arrow to move left.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _photos.length < 6 ? _photos.length + 1 : 6,
              itemBuilder: (ctx, index) {
                if (index == _photos.length && _photos.length < 6) {
                  return InkWell(
                    onTap: (_isUploadingPhoto || _isValidatingPhoto)
                        ? null
                        : _showAddPhotoSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: (_isUploadingPhoto || _isValidatingPhoto)
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: AppColors.primary, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'Add photo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }

                final photo = _photos[index];
                return Stack(
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Main',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (index > 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: GestureDetector(
                          onTap: () => _movePhotoLeft(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 14,
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
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
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
                );
              },
            ),
            if (_isValidatingPhoto) ...[
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Checking your pet\'s photo...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ] else if (_validationResult != null && _validationResult!.isValid) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _validationResult!.message,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_photoError != null) ...[
              const SizedBox(height: 8),
              Text(
                _photoError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
