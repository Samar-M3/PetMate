import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OwnerInfoPage extends ConsumerStatefulWidget {
  const OwnerInfoPage({super.key});

  @override
  ConsumerState<OwnerInfoPage> createState() => _OwnerInfoPageState();
}

class _OwnerInfoPageState extends ConsumerState<OwnerInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _bioController = TextEditingController();

  File? _selectedImage;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).user;
      if (user != null) {
        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          _phoneController.text = user.phoneNumber!;
        }
        if (user.profile?.fullName != null) {
          _nameController.text = user.profile!.fullName!;
        }
        if (user.profile?.location != null) {
          _locationController.text = user.profile!.location!;
        }
        if (user.profile?.area != null) {
          _areaController.text = user.profile!.area!;
        }
        if (user.profile?.bio != null) {
          _bioController.text = user.profile!.bio!;
        }
        if (user.profile?.effectiveImageUrl != null) {
          _uploadedImageUrl = user.profile!.effectiveImageUrl;
        } else if (user.profile?.profilePictureUrl != null) {
          _uploadedImageUrl = user.profile!.profilePictureUrl;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked == null) return; // Graceful cancel

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
              'Could not access image. Please check camera and photo permissions.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitOwnerProfile() async {
    if (!_formKey.currentState!.validate()) return;

    String? photoUrl = _uploadedImageUrl;
    if (photoUrl == null && (_imageBytes != null || _selectedImage != null)) {
      setState(() => _isUploadingImage = true);
      try {
        final cloudinary = ref.read(cloudinaryServiceProvider);
        photoUrl = await cloudinary.uploadUserAvatar(
          _selectedImage,
          bytes: _imageBytes,
          filename: _imageName,
        );
        _uploadedImageUrl = photoUrl;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload profile photo: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return; // Don't proceed on failed photo upload if an image was selected
      } finally {
        if (mounted) {
          setState(() => _isUploadingImage = false);
        }
      }
    }

    final success = await ref
        .read(authStateProvider.notifier)
        .completeOwnerProfile(
          fullName: _nameController.text.trim(),
          profilePictureUrl: photoUrl,
          imageUrl: photoUrl,
          location: _locationController.text.trim(),
          area: _areaController.text.trim(),
          bio: _bioController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Onboarding completed! Welcome to PetMate.'),
          backgroundColor: AppColors.success,
        ),
      );
      // Navigate to Home screen
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isBusy = authState.isLoading || _isUploadingImage;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Owner Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Now, tell us about yourself!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set up your owner profile so other pet parents and service providers can connect with you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Picture Picker with Preview
                Center(
                  child: GestureDetector(
                    onTap: isBusy ? null : _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.terracotta.withValues(
                                alpha: 0.5,
                              ),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _isUploadingImage
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : _imageBytes != null
                                ? Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                    width: 108,
                                    height: 108,
                                  )
                                : _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    width: 108,
                                    height: 108,
                                  )
                                : _uploadedImageUrl != null
                                ? AppNetworkImage(
                                    imageUrl: _uploadedImageUrl,
                                    width: 108,
                                    height: 108,
                                    shape: BoxShape.circle,
                                    fallbackIcon: Icons.person_outline,
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        size: 32,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Photo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
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

                // Error Banner
                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Full Name (Required)
                TextFormField(
                  controller: _nameController,
                  enabled: !isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. John Doe',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number (Required)
                TextFormField(
                  controller: _phoneController,
                  enabled: !isBusy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: 'e.g. 9812345678',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your contact phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location / City (Required)
                TextFormField(
                  controller: _locationController,
                  enabled: !isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Location / City *',
                    hintText: 'e.g. Kathmandu, Lalitpur, Pokhara',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your city/location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Area / Locality (Optional)
                TextFormField(
                  controller: _areaController,
                  enabled: !isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Area / Locality (Optional)',
                    hintText: 'e.g. Baneshwor, Jhamsikhel',
                    prefixIcon: Icon(
                      Icons.map_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bio (Optional)
                TextFormField(
                  controller: _bioController,
                  enabled: !isBusy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'About You (Optional Bio)',
                    hintText: 'Share a little about yourself and your pets...',
                    prefixIcon: Icon(
                      Icons.edit_note_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Complete Onboarding Button
                ElevatedButton(
                  onPressed: isBusy ? null : _submitOwnerProfile,
                  child: isBusy
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
                      : const Text('Complete Setup & Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
