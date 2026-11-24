import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pets/presentation/providers/pets_activation_provider.dart';

class PetInfoPage extends ConsumerStatefulWidget {
  const PetInfoPage({super.key});

  @override
  ConsumerState<PetInfoPage> createState() => _PetInfoPageState();
}

class _PetInfoPageState extends ConsumerState<PetInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customBreedController = TextEditingController();
  final _colorController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImage;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  String _selectedAnimalType = 'Dog';
  String _selectedBreed = 'Labrador';
  String _selectedGender = 'Male';
  DateTime? _selectedDob;
  String _selectedVaccination = 'Fully vaccinated';
  final Set<String> _selectedPersonalities = {'Friendly', 'Playful'};

  int _savedPetsCount = 0;

  final Map<String, List<String>> _breedsByAnimal = {
    'Dog': [
      'Labrador',
      'Golden Retriever',
      'German Shepherd',
      'Pug',
      'Husky',
      'Other',
    ],
    'Cat': [
      'Persian',
      'Siamese',
      'Maine Coon',
      'British Shorthair',
      'Bengal',
      'Other',
    ],
    'Rabbit': [
      'Holland Lop',
      'Netherland Dwarf',
      'Lionhead',
      'Mini Rex',
      'Other',
    ],
    'Bird': ['Parakeet', 'Cockatiel', 'Lovebird', 'Canary', 'Other'],
    'Other': ['Other'],
  };

  final List<String> _genders = ['Male', 'Female', 'Unknown'];
  final List<String> _vaccinationOptions = [
    'Fully vaccinated',
    'Partially vaccinated',
    'Not vaccinated',
    'Unknown',
  ];
  final List<String> _personalityOptions = [
    'Friendly',
    'Playful',
    'Calm',
    'Energetic',
    'Shy',
    'Independent',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _updateBreedListForAnimal('Dog');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customBreedController.dispose();
    _colorController.dispose();
    _allergiesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateBreedListForAnimal(String animal) {
    final list = _breedsByAnimal[animal] ?? ['Other'];
    _selectedBreed = list.first;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked == null) return; // User cancelled gracefully

      final bytes = await picked.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        if (!kIsWeb) {
          _selectedImage = File(picked.path);
        }
        _uploadedImageUrl = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access image. Please check camera and gallery permissions.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? now.subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cream,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  String _calculateAgeString(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    if (now.day < dob.day) {
      months--;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years <= 0 && months <= 0) {
      return 'Less than a month';
    }
    if (years <= 0) {
      return '$months ${months == 1 ? 'month' : 'months'} old';
    }
    if (months == 0) {
      return '$years ${years == 1 ? 'year' : 'years'} old';
    }
    return '$years yr $months mo old';
  }

  void _resetFormForNextPet() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _nameController.clear();
      _customBreedController.clear();
      _colorController.clear();
      _allergiesController.clear();
      _descriptionController.clear();
      _selectedAnimalType = 'Dog';
      _updateBreedListForAnimal('Dog');
      _selectedGender = 'Male';
      _selectedDob = null;
      _selectedVaccination = 'Fully vaccinated';
      _selectedPersonalities.clear();
      _selectedPersonalities.addAll(['Friendly', 'Playful']);
    });
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageBytes == null &&
        _selectedImage == null &&
        _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a photo for your pet.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your pet\'s date of birth.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String? photoUrl = _uploadedImageUrl;
    if (photoUrl == null && (_imageBytes != null || _selectedImage != null)) {
      setState(() => _isUploadingImage = true);
      try {
        final cloudinary = ref.read(cloudinaryServiceProvider);
        photoUrl = await cloudinary.uploadImage(
          _selectedImage,
          bytes: _imageBytes,
          filename: _imageName,
          folder: 'pets',
        );
        _uploadedImageUrl = photoUrl;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload pet photo: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return;
      } finally {
        if (mounted) {
          setState(() => _isUploadingImage = false);
        }
      }
    }

    final finalBreed =
        _selectedBreed == 'Other' &&
            _customBreedController.text.trim().isNotEmpty
        ? _customBreedController.text.trim()
        : _selectedBreed;

    final pet = await ref
        .read(authStateProvider.notifier)
        .addPet(
          name: _nameController.text.trim(),
          profilePictureUrl: photoUrl,
          imageUrl: photoUrl,
          animalType: _selectedAnimalType,
          breed: finalBreed,
          gender: _selectedGender,
          dateOfBirth: _selectedDob!,
          color: _colorController.text.trim(),
          personality: _selectedPersonalities.toList(),
          vaccinationStatus: _selectedVaccination,
          allergies: _allergiesController.text.trim(),
          description: _descriptionController.text.trim(),
        );

    if (pet != null && mounted) {
      try {
        await ref.read(petsActivationProvider.notifier).loadSummary();
      } catch (_) {}
      setState(() {
        _savedPetsCount++;
      });
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    final isOnboardingCompleted = ref
        .read(authStateProvider)
        .isOnboardingCompleted;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text(
              'Pet Profile Saved!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isOnboardingCompleted
              ? 'Your pet "${_nameController.text.trim()}" has been added successfully! You can add another pet now or return to your pets.'
              : 'Your pet "${_nameController.text.trim()}" has been added successfully. '
                    'You can add another pet profile now or continue to set up your owner profile.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 44),
              foregroundColor: AppColors.primary,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _resetFormForNextPet();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ready to add another pet!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('+ Add Another Pet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 44),
              backgroundColor: AppColors.terracotta,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (isOnboardingCompleted) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              } else {
                context.go('/onboarding/owner');
              }
            },
            child: Text(
              isOnboardingCompleted ? 'Done' : 'Continue to Owner Info',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final breeds = _breedsByAnimal[_selectedAnimalType] ?? ['Other'];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Pet Information'),
        actions: [
          if (_savedPetsCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_savedPetsCount added',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Titles
                const Text(
                  'Tell us about your furry friend!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Let's create a profile for your pet.",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Image Picker with Preview
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            image: (!_isUploadingImage)
                                ? (_imageBytes != null
                                      ? DecorationImage(
                                          image: MemoryImage(_imageBytes!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_selectedImage != null
                                            ? DecorationImage(
                                                image: FileImage(
                                                  _selectedImage!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null))
                                : null,
                          ),
                          child: _isUploadingImage
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                )
                              : (_imageBytes == null &&
                                    _selectedImage == null &&
                                    _uploadedImageUrl == null)
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Add Photo *',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        if (_imageBytes != null ||
                            _selectedImage != null ||
                            _uploadedImageUrl != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.terracotta,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Pet Name (Required)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Pet Name *',
                    hintText: 'e.g. Milo, Bella',
                    prefixIcon: Icon(Icons.pets, color: AppColors.primary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your pet\'s name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Animal Type (Required Dropdown)
                DropdownButtonFormField<String>(
                  initialValue: _selectedAnimalType,
                  decoration: const InputDecoration(
                    labelText: 'Animal Type *',
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  items: _breedsByAnimal.keys.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAnimalType = val;
                        _updateBreedListForAnimal(val);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Breed (Required Dropdown)
                DropdownButtonFormField<String>(
                  initialValue: breeds.contains(_selectedBreed)
                      ? _selectedBreed
                      : breeds.first,
                  decoration: const InputDecoration(
                    labelText: 'Breed *',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  items: breeds.map((b) {
                    return DropdownMenuItem(value: b, child: Text(b));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBreed = val;
                      });
                    }
                  },
                ),

                // Custom Breed input if "Other" is chosen
                if (_selectedBreed == 'Other') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customBreedController,
                    decoration: const InputDecoration(
                      labelText: 'Specify Breed *',
                      prefixIcon: Icon(
                        Icons.edit_note,
                        color: AppColors.primary,
                      ),
                    ),
                    validator: (val) {
                      if (_selectedBreed == 'Other' &&
                          (val == null || val.trim().isEmpty)) {
                        return 'Please enter the breed name';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Gender (Required Radio/Dropdown)
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: Icon(
                      Icons.transgender,
                      color: AppColors.primary,
                    ),
                  ),
                  items: _genders.map((g) {
                    return DropdownMenuItem(value: g, child: Text(g));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedGender = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Date of Birth (DatePicker with calculated Age display)
                InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth *',
                      prefixIcon: Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDob != null
                              ? DateFormat('MMM dd, yyyy').format(_selectedDob!)
                              : 'Select birth date',
                          style: TextStyle(
                            color: _selectedDob != null
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                        if (_selectedDob != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _calculateAgeString(_selectedDob!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Color (Optional)
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color (Optional)',
                    hintText: 'e.g. Golden, Black & White',
                    prefixIcon: Icon(
                      Icons.palette_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Personality Multi-select (Optional)
                const Text(
                  'Personality Traits',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _personalityOptions.map((trait) {
                    final isSelected = _selectedPersonalities.contains(trait);
                    return FilterChip(
                      label: Text(trait),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPersonalities.add(trait);
                          } else {
                            _selectedPersonalities.remove(trait);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Vaccination Status (Required)
                DropdownButtonFormField<String>(
                  initialValue: _selectedVaccination,
                  decoration: const InputDecoration(
                    labelText: 'Vaccination Status *',
                    prefixIcon: Icon(
                      Icons.health_and_safety_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  items: _vaccinationOptions.map((v) {
                    return DropdownMenuItem(value: v, child: Text(v));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedVaccination = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Allergies (Optional)
                TextFormField(
                  controller: _allergiesController,
                  decoration: const InputDecoration(
                    labelText: 'Allergies (Optional)',
                    hintText: 'e.g. Dairy, Pollen, Grain',
                    prefixIcon: Icon(
                      Icons.warning_amber_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Additional Description (Optional)
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional Description (Optional)',
                    hintText: 'Tell other pet parents more about your pet...',
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Save Pet Button
                ElevatedButton(
                  onPressed: (authState.isLoading || _isUploadingImage)
                      ? null
                      : _savePet,
                  child: (authState.isLoading || _isUploadingImage)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Save Pet Profile'),
                ),
                const SizedBox(height: 16),

                // If at least one pet is already saved, allow returning or continuing
                if (_savedPetsCount > 0)
                  TextButton(
                    onPressed: () {
                      if (authState.isOnboardingCompleted) {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      } else {
                        context.go('/onboarding/owner');
                      }
                    },
                    child: Text(
                      authState.isOnboardingCompleted
                          ? 'Done. Return to Pets →'
                          : 'I have added all my pets. Continue to Owner Information →',
                      style: const TextStyle(
                        color: AppColors.terracotta,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
