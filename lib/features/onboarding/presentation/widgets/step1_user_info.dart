import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/nepal_districts.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_scaffold.dart';

class Step1UserInfo extends ConsumerStatefulWidget {
  const Step1UserInfo({super.key});

  @override
  ConsumerState<Step1UserInfo> createState() => _Step1UserInfoState();
}

class _Step1UserInfoState extends ConsumerState<Step1UserInfo> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedDistrict;

  Uint8List? _localImageBytes;
  File? _localImageFile;
  String? _localFileName;
  String? _uploadedAvatarUrl;
  String? _uploadedAvatarPublicId;
  bool _isUploadingAvatar = false;
  String? _uploadError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    if (_initialized) return;
    _initialized = true;
    final onboarding = ref.read(onboardingProvider);
    final authState = ref.read(authStateProvider);
    final profile = onboarding.profile;
    final user = authState.user;
    final fbUser = authState.firebaseUser;

    _nameController.text = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (user?.profile?.fullName ?? fbUser?.displayName ?? '');

    _emailController.text = profile?.email.isNotEmpty == true
        ? profile!.email
        : (user?.email ?? fbUser?.email ?? '');

    final dist = profile?.district.isNotEmpty == true
        ? profile!.district
        : (profile?.city.isNotEmpty == true
            ? profile!.city
            : (user?.profile?.location ?? ''));
    if (dist.isNotEmpty) {
      setState(() => _selectedDistrict = dist);
    }

    _uploadedAvatarUrl =
        profile?.avatarUrl ?? user?.profile?.effectiveImageUrl;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarSource() async {
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
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked == null) return;

      final ext = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        setState(() {
          _uploadError = 'Only JPG, PNG, and WebP images are allowed.';
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _uploadError = 'Image is larger than 5 MB. Please choose a smaller photo.';
        });
        return;
      }

      setState(() {
        _localImageBytes = bytes;
        _localFileName = picked.name;
        _localImageFile = kIsWeb ? null : File(picked.path);
        _uploadedAvatarUrl = null;
        _uploadError = null;
      });

      await _uploadAvatar();
    } catch (_) {
      setState(() {
        _uploadError = 'Could not access camera or gallery. Check permissions.';
      });
    }
  }

  Future<bool> _uploadAvatar() async {
    if (_localImageBytes == null && _localImageFile == null) return true;
    setState(() {
      _isUploadingAvatar = true;
      _uploadError = null;
    });
    try {
      final asset = await ref.read(onboardingProvider.notifier).uploadPublicImage(
            file: _localImageFile,
            bytes: _localImageBytes,
            filename: _localFileName ?? 'avatar.jpg',
            folder: 'users',
          );
      setState(() {
        _uploadedAvatarUrl = asset.url;
        _uploadedAvatarPublicId = asset.publicId;
        _isUploadingAvatar = false;
      });
      return true;
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
        _uploadError = 'Photo upload failed. Check your connection and retry.';
      });
      return false;
    }
  }

  Future<void> _openDistrictPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DistrictSearchSheet(initialValue: _selectedDistrict),
    );
    if (selected != null) {
      setState(() => _selectedDistrict = selected);
    }
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingAvatar) return;

    if (_localImageBytes != null && _uploadedAvatarUrl == null) {
      final uploaded = await _uploadAvatar();
      if (!uploaded) return;
    }

    final district = _selectedDistrict!.trim();
    await ref.read(onboardingProvider.notifier).saveStep1(
          displayName: _nameController.text.trim(),
          avatarUrl: _uploadedAvatarUrl,
          avatarPublicId: _uploadedAvatarPublicId,
          city: district,
          district: district,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      step: 1,
      title: 'Tell us about you',
      subtitle: 'This helps nearby pet owners in Nepal know who you are.',
      isSaving: state.isSaving || _isUploadingAvatar,
      errorMessage: _uploadError ?? state.errorMessage,
      onRetry: _uploadError != null ? _uploadAvatar : _onNext,
      onNext: _onNext,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Circular Profile Photo (Optional)
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAvatarSource,
                    child: Stack(
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: _localImageBytes != null
                                ? Image.memory(
                                    _localImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : (_uploadedAvatarUrl != null &&
                                        _uploadedAvatarUrl!.isNotEmpty
                                    ? AppNetworkImage(
                                        imageUrl: _uploadedAvatarUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person_outline_rounded,
                                        size: 52,
                                        color: AppColors.textMuted,
                                      )),
                          ),
                        ),
                        if (_isUploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profile photo (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Full Name (Required)
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full name *',
                hintText: 'e.g. Aarav Shrestha',
                prefixIcon: const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 2) {
                  return 'Please enter your full name (at least 2 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email (Read-only)
            TextFormField(
              controller: _emailController,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email (login email)',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // City / District (Required, Searchable Nepal Districts)
            FormField<String>(
              initialValue: _selectedDistrict,
              validator: (_) {
                if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
                  return 'Please select your city or district';
                }
                return null;
              },
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _openDistrictPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'City / District *',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          filled: true,
                          fillColor: Colors.white,
                          errorText: field.errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _selectedDistrict ?? 'Select your district in Nepal',
                          style: TextStyle(
                            fontSize: 15,
                            color: _selectedDistrict == null
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'We only show your city or district, never your exact street address.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistrictSearchSheet extends StatefulWidget {
  final String? initialValue;
  const _DistrictSearchSheet({this.initialValue});

  @override
  State<_DistrictSearchSheet> createState() => _DistrictSearchSheetState();
}

class _DistrictSearchSheetState extends State<_DistrictSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = nepalDistricts
        .where((d) => d.toLowerCase().contains(_query.toLowerCase().trim()))
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select City / District',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search Nepal districts (e.g. Kathmandu, Pokhara)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final district = filtered[i];
                final isSelected = district == widget.initialValue;
                return ListTile(
                  title: Text(
                    district,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, district),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
