import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../data/repositories/seller_repository.dart';
import '../providers/seller_provider.dart';

class SellerRegistrationPage extends ConsumerStatefulWidget {
  const SellerRegistrationPage({super.key});

  @override
  ConsumerState<SellerRegistrationPage> createState() =>
      _SellerRegistrationPageState();
}

class _SellerRegistrationPageState
    extends ConsumerState<SellerRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal Information
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Business Information
  final _storeNameController = TextEditingController();
  String _businessType = 'INDIVIDUAL'; // 'INDIVIDUAL' or 'REGISTERED_BUSINESS'
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController(text: 'Bagmati Province');
  final _postalCodeController = TextEditingController();

  // Verification Documents
  String? _registrationDocUrl;
  String? _registrationDocName;
  bool _isUploadingRegDoc = false;

  String? _identityDocUrl;
  String? _identityDocName;
  bool _isUploadingIdDoc = false;

  // Registration Options
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadDocument({required bool isRegistrationDoc}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      File? file;
      if (!kIsWeb) {
        file = File(picked.path);
      }

      setState(() {
        if (isRegistrationDoc) {
          _isUploadingRegDoc = true;
          _registrationDocName = picked.name;
        } else {
          _isUploadingIdDoc = true;
          _identityDocName = picked.name;
        }
      });

      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadSellerDocument(
        file,
        bytes: bytes,
        filename: picked.name,
      );

      if (mounted) {
        setState(() {
          if (isRegistrationDoc) {
            _registrationDocUrl = url;
            _isUploadingRegDoc = false;
          } else {
            _identityDocUrl = url;
            _isUploadingIdDoc = false;
          }
        });

        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${isRegistrationDoc ? "Business registration" : "Identity"} document uploaded successfully!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isRegistrationDoc) {
            _isUploadingRegDoc = false;
          } else {
            _isUploadingIdDoc = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitRegistration() async {
    ref.read(sellerProvider.notifier).clearMessages();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the highlighted errors in the form.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must accept the PetMate Seller Terms & Conditions to register.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must accept the PetMate Privacy Policy to register.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_businessType == 'REGISTERED_BUSINESS' &&
        (_registrationDocUrl == null || _registrationDocUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registered businesses must provide a company or PAN/VAT registration document.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final request = SellerRegistrationRequest(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      storeName: _storeNameController.text.trim(),
      businessType: _businessType,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      businessAddress: _addressController.text.trim(),
      city: _cityController.text.trim(),
      province: _provinceController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      registrationDocUrl: _registrationDocUrl,
      identityDocUrl: _identityDocUrl,
      termsAccepted: _termsAccepted,
      privacyAccepted: _privacyAccepted,
    );

    final success = await ref
        .read(sellerProvider.notifier)
        .registerSeller(request);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seller registration submitted! Redirecting to application status...',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/seller/status');
      } else {
        final error =
            ref.read(sellerProvider).errorMessage ??
            'Registration failed. Please check your information.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerState = ref.watch(sellerProvider);
    final isLoading = sellerState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text(
          'Seller Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text(
              'Log In',
              style: TextStyle(
                color: AppColors.terracotta,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner (Mobile-Optimized)
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),

                    // Section A: Personal Information
                    _buildSectionCard(
                      title: 'A. Personal Information',
                      subtitle: 'Owner contact & authentication credentials',
                      icon: Icons.person_outline_rounded,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Full Name *',
                            hint: 'e.g. Aarav Sharma',
                            icon: Icons.badge_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            if (value.trim().length < 2) {
                              return 'Please enter a valid full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Email Address *',
                            hint: 'seller@example.com',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email address is required';
                            }
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: _inputDecoration(
                            label: 'Phone Number *',
                            hint: '98XXXXXXXX (10 digits)',
                            icon: Icons.phone_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                              return 'Phone number must be exactly 10 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Password *',
                            hint: 'Min 6 characters (letters & numbers)',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)')
                                .hasMatch(value)) {
                              return 'Password must contain at least one letter and one number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Confirm Password *',
                            hint: 'Re-enter your password',
                            icon: Icons.lock_reset_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section B: Business Information
                    _buildSectionCard(
                      title: 'B. Business Information',
                      subtitle:
                          'Store details displayed on PetMate marketplace',
                      icon: Icons.storefront_outlined,
                      children: [
                        TextFormField(
                          controller: _storeNameController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Store Name *',
                            hint: 'e.g. Kathmandu Pet Care Store',
                            icon: Icons.storefront_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Store name is required';
                            }
                            if (value.trim().length < 2) {
                              return 'Store name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Business Type *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildBusinessTypeChoice(
                          type: 'INDIVIDUAL',
                          title: 'Individual Seller',
                          subtitle:
                              'Home breeder, pet accessories, or hobbyist',
                        ),
                        const SizedBox(height: 8),
                        _buildBusinessTypeChoice(
                          type: 'REGISTERED_BUSINESS',
                          title: 'Registered Business',
                          subtitle:
                              'Registered company, clinic, PAN or VAT entity',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Store Description (Optional)',
                            hint: 'What products or specialties does your shop offer?',
                            icon: Icons.description_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _addressController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Business Address *',
                            hint: 'Street name or area',
                            icon: Icons.location_on_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Business address is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cityController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'City *',
                            hint: 'e.g. Kathmandu, Lalitpur, Pokhara',
                            icon: Icons.location_city_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'City is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _provinceController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Province *',
                            hint: 'e.g. Bagmati Province',
                            icon: Icons.map_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Province is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _postalCodeController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: _inputDecoration(
                            label: 'Postal Code *',
                            hint: 'e.g. 44600',
                            icon: Icons.markunread_mailbox_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Postal code is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section C: Verification Documents
                    _buildSectionCard(
                      title: 'C. Verification Documents',
                      subtitle:
                          'Ensure trust and safety on the PetMate marketplace',
                      icon: Icons.verified_user_outlined,
                      children: [
                        _buildDocumentUploader(
                          title: 'Business Registration Document',
                          subtitle: _businessType == 'REGISTERED_BUSINESS'
                              ? 'Required: Upload PAN, VAT, or Registration Certificate'
                              : 'Optional: Upload PAN certificate if available',
                          isRequired: _businessType == 'REGISTERED_BUSINESS',
                          docUrl: _registrationDocUrl,
                          docName: _registrationDocName,
                          isUploading: _isUploadingRegDoc,
                          onPick: () =>
                              _pickAndUploadDocument(isRegistrationDoc: true),
                          onClear: () {
                            setState(() {
                              _registrationDocUrl = null;
                              _registrationDocName = null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildDocumentUploader(
                          title: 'Identity Verification Document',
                          subtitle: 'Recommended: Citizenship, National ID, or Passport',
                          isRequired: false,
                          docUrl: _identityDocUrl,
                          docName: _identityDocName,
                          isUploading: _isUploadingIdDoc,
                          onPick: () =>
                              _pickAndUploadDocument(isRegistrationDoc: false),
                          onClear: () {
                            setState(() {
                              _identityDocUrl = null;
                              _identityDocName = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section D: Registration Options
                    _buildSectionCard(
                      title: 'D. Registration Options',
                      subtitle: 'Review and accept marketplace terms',
                      icon: Icons.check_circle_outline_rounded,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _termsAccepted = !_termsAccepted;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _termsAccepted,
                                  activeColor: AppColors.terracotta,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (val) {
                                    setState(() {
                                      _termsAccepted = val ?? false;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'I agree to the Seller Terms of Service *',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Commitment to sell authentic pet products with fair pricing and prompt order handling.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _privacyAccepted = !_privacyAccepted;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _privacyAccepted,
                                  activeColor: AppColors.terracotta,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (val) {
                                    setState(() {
                                      _privacyAccepted = val ?? false;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'I accept the PetMate Privacy Policy *',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Safe and lawful handling of customer delivery details and personal data.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 1,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Register as Seller',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already registered? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: const Text(
                                'Sign In Here',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.terracotta,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(
                              Icons.home_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: const Text(
                              'Return to Main PetMate Home',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.terracotta.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 28,
              color: AppColors.terracotta,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join as a PetMate Seller',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Open your storefront, list products, and reach thousands of pet parents across Nepal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.terracotta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBusinessTypeChoice({
    required String type,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _businessType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _businessType = type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terracotta.withValues(alpha: 0.08)
              : AppColors.inputFill,
          border: Border.all(
            color: isSelected ? AppColors.terracotta : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppColors.terracotta : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.terracottaDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploader({
    required String title,
    required String subtitle,
    required bool isRequired,
    required String? docUrl,
    required String? docName,
    required bool isUploading,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasDoc = docUrl != null && docUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDoc ? AppColors.success : AppColors.border,
          width: hasDoc ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title + (isRequired ? ' *' : ''),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (hasDoc)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Attached',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (isUploading)
            const Row(
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.terracotta,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Uploading document securely...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          else if (hasDoc)
            Row(
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    docName ?? 'Document attached',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Remove',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.error,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(
                  Icons.upload_file_outlined,
                  size: 18,
                  color: AppColors.terracotta,
                ),
                label: const Text(
                  'Select & Upload Document',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.terracotta,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.terracotta),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    );
  }
}
