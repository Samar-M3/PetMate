import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/nepal_districts.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_scaffold.dart';

class Step3MatingDetails extends ConsumerStatefulWidget {
  const Step3MatingDetails({super.key});

  @override
  ConsumerState<Step3MatingDetails> createState() => _Step3MatingDetailsState();
}

class _Step3MatingDetailsState extends ConsumerState<Step3MatingDetails> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _colorCoatController = TextEditingController();
  final _litterCountController = TextEditingController();
  final _bioController = TextEditingController();

  String _purpose = 'BOTH';
  bool _isNeutered = false;
  bool _hasLitters = false;
  final Set<String> _temperaments = {};
  String? _sizeCategory;
  bool _hasPedigree = false;
  String? _pedigreeCertUrl;
  bool _isUploadingCert = false;
  String? _certUploadError;
  String? _locationDistrict;
  bool _initialized = false;

  static const List<String> _temperamentOptions = [
    'Friendly',
    'Calm',
    'Energetic',
    'Shy',
    'Aggressive',
    'Good with other pets',
  ];

  @override
  void initState() {
    super.initState();
    _bioController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    if (_initialized) return;
    _initialized = true;
    final state = ref.read(onboardingProvider);
    final pet = state.pet;
    final profile = state.profile;

    if (pet != null) {
      _purpose = pet.purpose;
      _isNeutered = pet.isNeutered;
      _hasLitters = pet.hasLitters ?? false;
      if (pet.litterCount != null) {
        _litterCountController.text = pet.litterCount.toString();
      }
      _temperaments
        ..clear()
        ..addAll(pet.temperament);
      if (pet.weightKg != null) {
        _weightController.text = pet.weightKg!.toString();
      }
      _sizeCategory = pet.sizeCategory;
      _colorCoatController.text = pet.colorCoat ?? '';
      _hasPedigree = pet.hasPedigree;
      _pedigreeCertUrl = pet.pedigreeCertUrl;
      _bioController.text = pet.bio ?? '';
      _locationDistrict = pet.district ?? pet.city;
    }

    if (_locationDistrict == null || _locationDistrict!.isEmpty) {
      _locationDistrict =
          profile?.district.isNotEmpty == true ? profile!.district : profile?.city;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _weightController.dispose();
    _colorCoatController.dispose();
    _litterCountController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPedigreeCert() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;

      final ext = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        setState(() {
          _certUploadError = 'Only JPG, PNG, and WebP images are allowed.';
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _certUploadError = 'Certificate image must be under 5 MB.';
        });
        return;
      }

      setState(() {
        _isUploadingCert = true;
        _certUploadError = null;
      });

      final asset = await ref.read(onboardingProvider.notifier).uploadPublicImage(
            file: kIsWeb ? null : File(picked.path),
            bytes: bytes,
            filename: picked.name,
            folder: 'pets',
          );

      setState(() {
        _pedigreeCertUrl = asset.url;
        _isUploadingCert = false;
      });
    } catch (_) {
      setState(() {
        _isUploadingCert = false;
        _certUploadError = 'Certificate upload failed. Tap to try again.';
      });
    }
  }

  Future<void> _openLocationPicker() async {
    String query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = nepalDistricts
              .where((d) => d.toLowerCase().contains(query.toLowerCase().trim()))
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Nepal city / district',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(filtered[i]),
                      onTap: () => Navigator.pop(ctx, filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (selected != null) {
      setState(() => _locationDistrict = selected);
    }
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingCert) return;

    final weight = double.tryParse(_weightController.text.trim());
    final isCompanionOnly = _purpose == 'COMPANION';

    await ref.read(onboardingProvider.notifier).saveStep3({
      'purpose': _purpose,
      'isNeutered': _isNeutered,
      if (!isCompanionOnly && !_isNeutered) ...{
        'hasLitters': _hasLitters,
        if (_hasLitters && _litterCountController.text.trim().isNotEmpty)
          'litterCount': int.tryParse(_litterCountController.text.trim()),
      },
      'temperament': _temperaments.toList(),
      'weightKg': ?weight,
      if (_sizeCategory != null) 'sizeCategory': _sizeCategory,
      if (_colorCoatController.text.trim().isNotEmpty)
        'colorCoat': _colorCoatController.text.trim(),
      if (!isCompanionOnly) ...{
        'hasPedigree': _hasPedigree,
        if (_hasPedigree && _pedigreeCertUrl != null)
          'pedigreeCertUrl': _pedigreeCertUrl,
      } else
        'hasPedigree': false,
      if (_bioController.text.trim().isNotEmpty)
        'bio': _bioController.text.trim(),
      if (_locationDistrict != null && _locationDistrict!.isNotEmpty) ...{
        'city': _locationDistrict,
        'district': _locationDistrict,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final isFemale = state.pet?.gender.toUpperCase() == 'FEMALE';
    final isCompanionOnly = _purpose == 'COMPANION';
    final showPreviousLitters = !isCompanionOnly && isFemale && !_isNeutered;

    return OnboardingScaffold(
      step: 3,
      title: 'Mating & personality',
      subtitle: 'Tell us what you are looking for and describe your pet.',
      isSaving: state.isSaving || _isUploadingCert,
      errorMessage: _certUploadError ?? state.errorMessage,
      onBack: () => ref.read(onboardingProvider.notifier).goBack(),
      onSkip: () => ref.read(onboardingProvider.notifier).skipStep3(),
      onRetry: _onNext,
      onNext: _onNext,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Purpose (Required)
            const Text(
              'Purpose *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _PurposeOption(
              title: 'Companion only',
              subtitle: 'Just browsing, events & community',
              selected: _purpose == 'COMPANION',
              onTap: () => setState(() => _purpose = 'COMPANION'),
            ),
            const SizedBox(height: 8),
            _PurposeOption(
              title: 'Looking for a mate',
              subtitle: 'Show my pet in mating discovery',
              selected: _purpose == 'MATING',
              onTap: () => setState(() => _purpose = 'MATING'),
            ),
            const SizedBox(height: 8),
            _PurposeOption(
              title: 'Open to both',
              subtitle: 'Playdates and mating matches',
              selected: _purpose == 'BOTH',
              onTap: () => setState(() => _purpose = 'BOTH'),
            ),
            const SizedBox(height: 18),

            // Neutered or spayed
            const Text(
              'Neutered or spayed?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChoicePill(
                    label: 'No',
                    selected: !_isNeutered,
                    onTap: () => setState(() => _isNeutered = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoicePill(
                    label: 'Yes',
                    selected: _isNeutered,
                    onTap: () => setState(() => _isNeutered = true),
                  ),
                ),
              ],
            ),
            if (_isNeutered) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.info),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Neutered pets are not shown in mating results.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Previous Litters (only if Female, not neutered, and not Companion only)
            if (showPreviousLitters) ...[
              const Text(
                'Previous litters (optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ChoicePill(
                      label: 'No',
                      selected: !_hasLitters,
                      onTap: () => setState(() => _hasLitters = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoicePill(
                      label: 'Yes',
                      selected: _hasLitters,
                      onTap: () => setState(() => _hasLitters = true),
                    ),
                  ),
                ],
              ),
              if (_hasLitters) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _litterCountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'How many litters?',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ],

            // Temperament (Multi-select chips)
            const Text(
              'Temperament (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _temperamentOptions.map((item) {
                final selected = _temperaments.contains(item);
                return FilterChip(
                  label: Text(item),
                  selected: selected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.16),
                  checkmarkColor: AppColors.primaryDark,
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _temperaments.add(item);
                      } else {
                        _temperaments.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Weight & Size Category
            const Text(
              'Size & weight (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChoicePill(
                    label: 'Small',
                    selected: _sizeCategory == 'SMALL',
                    onTap: () => setState(() => _sizeCategory = 'SMALL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoicePill(
                    label: 'Medium',
                    selected: _sizeCategory == 'MEDIUM',
                    onTap: () => setState(() => _sizeCategory = 'MEDIUM'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoicePill(
                    label: 'Large',
                    selected: _sizeCategory == 'LARGE',
                    onTap: () => setState(() => _sizeCategory = 'LARGE'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight in kg (optional)',
                hintText: 'e.g. 12.5',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a positive weight in kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Colour and coat
            TextFormField(
              controller: _colorCoatController,
              decoration: InputDecoration(
                labelText: 'Colour and coat (optional)',
                hintText: 'e.g. Golden, short smooth coat',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pedigree (Hidden if Companion only)
            if (!isCompanionOnly) ...[
              const Text(
                'Pedigree or registration? (optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ChoicePill(
                      label: 'No',
                      selected: !_hasPedigree,
                      onTap: () => setState(() => _hasPedigree = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoicePill(
                      label: 'Yes',
                      selected: _hasPedigree,
                      onTap: () => setState(() => _hasPedigree = true),
                    ),
                  ),
                ],
              ),
              if (_hasPedigree) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isUploadingCert ? null : _pickPedigreeCert,
                  icon: Icon(
                    _pedigreeCertUrl != null
                        ? Icons.check_circle_outline
                        : Icons.upload_file_outlined,
                    color: _pedigreeCertUrl != null
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                  label: Text(
                    _isUploadingCert
                        ? 'Uploading certificate...'
                        : (_pedigreeCertUrl != null
                            ? 'Certificate uploaded (tap to replace)'
                            : 'Upload certificate image (optional)'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Short bio (max 150 chars with live counter)
            TextFormField(
              controller: _bioController,
              maxLength: 150,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Short bio (optional)',
                hintText: 'Friendly, loves morning walks in Patan...',
                counterText: '${_bioController.text.length}/150',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (v) {
                if (v != null && v.length > 150) {
                  return 'Bio must be 150 characters or fewer';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Location (City / District only)
            InkWell(
              onTap: _openLocationPicker,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Location (City / District)',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _locationDistrict?.isNotEmpty == true
                      ? _locationDistrict!
                      : 'Select Nepal district',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurposeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PurposeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
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
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
