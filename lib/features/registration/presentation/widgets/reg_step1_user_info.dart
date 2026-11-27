import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/nepal_districts.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../providers/registration_provider.dart';

class RegStep1UserInfo extends ConsumerStatefulWidget {
  const RegStep1UserInfo({super.key});

  @override
  ConsumerState<RegStep1UserInfo> createState() => RegStep1UserInfoState();
}

class RegStep1UserInfoState extends ConsumerState<RegStep1UserInfo> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  String? _selectedDistrict;
  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  File? _avatarFile;
  Uint8List? _avatarBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final regState = ref.read(registrationProvider);

    _nameController = TextEditingController(text: regState.fullName);
    _emailController = TextEditingController(text: regState.email);
    _phoneController = TextEditingController(text: regState.phoneNumber);
    _passwordController = TextEditingController(text: regState.password);
    _confirmPasswordController =
        TextEditingController(text: regState.confirmPassword);
    _selectedDistrict =
        regState.district.isNotEmpty ? regState.district : null;
    _termsAccepted = regState.termsAccepted;
    _avatarFile = regState.avatarFile;
    _avatarBytes = regState.avatarBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _persistLocalState() {
    ref.read(registrationProvider.notifier).updateStep1Data(
          fullName: _nameController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
          city: _selectedDistrict ?? '',
          district: _selectedDistrict ?? '',
          termsAccepted: _termsAccepted,
          avatarFile: _avatarFile,
          avatarBytes: _avatarBytes,
        );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avatar image must be under 5 MB.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _avatarFile = File(picked.path);
          _avatarBytes = bytes;
        });
        _persistLocalState();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_avatarBytes != null || _avatarFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Remove photo', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarFile = null;
                      _avatarBytes = null;
                    });
                    _persistLocalState();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistrictPicker() {
    final searchController = TextEditingController();
    List<String> filtered = List.from(nepalDistricts);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select City / District',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search district (e.g. Kathmandu)...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (query) {
                          setModalState(() {
                            filtered = nepalDistricts
                                .where((d) =>
                                    d.toLowerCase().contains(query.toLowerCase().trim()))
                                .toList();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final district = filtered[index];
                            final isSelected = district == _selectedDistrict;
                            return ListTile(
                              title: Text(
                                district,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check, color: AppColors.primary)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedDistrict = district;
                                });
                                _persistLocalState();
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> submit() async {
    _persistLocalState();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your city / district.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be 18+ and accept the Terms and Privacy Policy.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref.read(registrationProvider.notifier).submitStep1(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          password: _passwordController.text,
          city: _selectedDistrict!,
          district: _selectedDistrict!,
          termsAccepted: _termsAccepted,
          avatarFile: _avatarFile,
          avatarBytes: _avatarBytes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(registrationProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Photo Picker (Optional)
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _showImageSourcePicker,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.creamDark,
                      border: Border.all(color: AppColors.primaryLight, width: 2.5),
                    ),
                    child: ClipOval(
                      child: _avatarBytes != null
                          ? Image.memory(
                              _avatarBytes!,
                              fit: BoxFit.cover,
                            )
                          : (regState.avatarUrl != null && regState.avatarUrl!.isNotEmpty
                              ? AppNetworkImage(
                                  imageUrl: regState.avatarUrl!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.person_outline_rounded,
                                  size: 52,
                                  color: AppColors.textMuted,
                                )),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImageSourcePicker,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Profile Photo (Optional)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),

          // Full Name
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g. Aayush Sharma',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
            ),
            onChanged: (_) => _persistLocalState(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (v.trim().length < 2) {
                return 'Full name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
            ),
            onChanged: (_) => _persistLocalState(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your email address';
              }
              final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!regex.hasMatch(v.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number (Nepal format)
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Nepal Mobile Number *',
              hintText: '98XXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
            ),
            onChanged: (_) => _persistLocalState(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your mobile number';
              }
              final clean = v.trim();
              if (!RegExp(r'^(?:98|97)\d{8}$|^\d{10}$').hasMatch(clean)) {
                return 'Must be a 10-digit mobile number (e.g. 98XXXXXXXX)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              hintText: 'Minimum 8 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => _persistLocalState(),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please create a password';
              }
              if (v.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            onChanged: (_) => _persistLocalState(),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your password';
              }
              if (v != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // District / City Dropdown
          InkWell(
            onTap: _showDistrictPicker,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'City / District *',
                hintText: 'Select your Nepal district',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ),
              child: Text(
                _selectedDistrict ?? 'Select district',
                style: TextStyle(
                  color: _selectedDistrict != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Terms and Privacy Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _termsAccepted,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      _termsAccepted = val ?? false;
                    });
                    _persistLocalState();
                  },
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'I am 18+ years of age and agree to PetMate\'s Terms of Service and Privacy Policy.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
