import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/nepal_districts.dart';
import '../../data/registration_service.dart';
import '../providers/registration_provider.dart';

class RegStep3MatingDetails extends ConsumerStatefulWidget {
  const RegStep3MatingDetails({super.key});

  @override
  ConsumerState<RegStep3MatingDetails> createState() => RegStep3MatingDetailsState();
}

class RegStep3MatingDetailsState extends ConsumerState<RegStep3MatingDetails> {
  final _formKey = GlobalKey<FormState>();

  String _purpose = 'MATING'; // 'COMPANION', 'MATING', 'BOTH'
  bool _isNeutered = false;
  bool _hasLitters = false;
  late TextEditingController _litterCountController;
  final List<String> _selectedTemperaments = [];
  late TextEditingController _weightController;
  String? _sizeCategory; // 'SMALL', 'MEDIUM', 'LARGE'
  late TextEditingController _colorCoatController;
  bool _hasPedigree = false;
  String? _pedigreeCertUrl;
  bool _isUploadingCert = false;
  late TextEditingController _bioController;
  String? _selectedLocation;

  final List<String> _temperamentOptions = [
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
    final regState = ref.read(registrationProvider);
    final pet = regState.pet;

    _purpose = pet?.purpose ?? 'MATING';
    _isNeutered = pet?.isNeutered ?? false;
    _hasLitters = pet?.hasLitters ?? false;
    _litterCountController = TextEditingController(
      text: pet?.litterCount != null && pet!.litterCount! > 0
          ? pet.litterCount.toString()
          : '',
    );
    if (pet != null && pet.temperament.isNotEmpty) {
      _selectedTemperaments.addAll(pet.temperament);
    }
    _weightController = TextEditingController(
      text: pet?.weightKg != null && pet!.weightKg! > 0
          ? pet.weightKg.toString()
          : '',
    );
    _sizeCategory = pet?.sizeCategory;
    _colorCoatController = TextEditingController(text: pet?.colorCoat ?? '');
    _hasPedigree = pet?.hasPedigree ?? false;
    _pedigreeCertUrl = pet?.pedigreeCertUrl;
    _bioController = TextEditingController(text: pet?.bio ?? '');

    _selectedLocation = pet?.district?.isNotEmpty == true
        ? pet!.district
        : (regState.district.isNotEmpty ? regState.district : null);
  }

  @override
  void dispose() {
    _litterCountController.dispose();
    _weightController.dispose();
    _colorCoatController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPedigreeCert() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingCert = true);
      final asset = await ref.read(registrationServiceProvider).uploadImage(
            file: File(picked.path),
            folder: 'pedigree_certs',
          );
      if (mounted) {
        setState(() {
          _pedigreeCertUrl = asset.url;
          _isUploadingCert = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCert = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload certificate: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
                        'Select Pet Location',
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
                          hintText: 'Search district...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (q) {
                          setModalState(() {
                            filtered = nepalDistricts
                                .where((d) =>
                                    d.toLowerCase().contains(q.toLowerCase().trim()))
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
                            final isSelected = district == _selectedLocation;
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
                                setState(() => _selectedLocation = district);
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
    if (!_formKey.currentState!.validate()) return;

    final weight = double.tryParse(_weightController.text.trim());
    final litters = int.tryParse(_litterCountController.text.trim());

    final payload = <String, dynamic>{
      'purpose': _purpose,
      'isNeutered': _isNeutered,
      'temperament': _selectedTemperaments,
      if (weight != null && weight > 0) 'weightKg': weight,
      if (_sizeCategory != null) 'sizeCategory': _sizeCategory,
      if (_colorCoatController.text.trim().isNotEmpty)
        'colorCoat': _colorCoatController.text.trim(),
      'hasPedigree': _hasPedigree,
      if (_hasPedigree && _pedigreeCertUrl != null)
        'pedigreeCertUrl': _pedigreeCertUrl,
      if (_bioController.text.trim().isNotEmpty)
        'bio': _bioController.text.trim(),
      if (_selectedLocation != null) ...{
        'city': _selectedLocation,
        'district': _selectedLocation,
      },
    };

    final isFemale =
        ref.read(registrationProvider).pet?.gender.toUpperCase() == 'FEMALE';
    if (isFemale && !_isNeutered && _purpose != 'COMPANION') {
      payload['hasLitters'] = _hasLitters;
      if (_hasLitters && litters != null) {
        payload['litterCount'] = litters;
      }
    }

    await ref.read(registrationProvider.notifier).submitStep3(payload);
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(registrationProvider).pet;
    final isFemale = pet?.gender.toUpperCase() == 'FEMALE';
    final isCompanionOnly = _purpose == 'COMPANION';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Purpose Selector (Required)
          const Text(
            'Purpose *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _PurposeOption(
            title: 'Companion only',
            subtitle: 'Not looking for mating; pure friendship and companionship.',
            isSelected: _purpose == 'COMPANION',
            onTap: () => setState(() => _purpose = 'COMPANION'),
          ),
          const SizedBox(height: 8),
          _PurposeOption(
            title: 'Looking for a mate',
            subtitle: 'Actively searching for breeding and mating partners.',
            isSelected: _purpose == 'MATING',
            onTap: () => setState(() => _purpose = 'MATING'),
          ),
          const SizedBox(height: 8),
          _PurposeOption(
            title: 'Open to both',
            subtitle: 'Happy to connect for playdates or mating opportunities.',
            isSelected: _purpose == 'BOTH',
            onTap: () => setState(() => _purpose = 'BOTH'),
          ),
          const SizedBox(height: 20),

          // Neutered / Spayed Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Neutered or Spayed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Has your pet undergone desexing?',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Switch(
                value: _isNeutered,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _isNeutered = val),
              ),
            ],
          ),

          if (_isNeutered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Neutered pets are not shown in mating results.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Previous Litters (Only for Female + Not Neutered + Not Companion)
          if (isFemale && !_isNeutered && !isCompanionOnly) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous Litters',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Has she had puppies/kittens before?',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Switch(
                  value: _hasLitters,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _hasLitters = val),
                ),
              ],
            ),
            if (_hasLitters) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _litterCountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Number of Litters',
                  hintText: 'e.g. 1 or 2',
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Temperament Multi-select chips
          const Text(
            'Temperament',
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
            children: _temperamentOptions.map((t) {
              final isSelected = _selectedTemperaments.contains(t);
              return FilterChip(
                label: Text(t),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.18),
                checkmarkColor: AppColors.primaryDark,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTemperaments.add(t);
                    } else {
                      _selectedTemperaments.remove(t);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Size & Weight
          const Text(
            'Size or Weight',
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
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'e.g. 12.5',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sizeCategory,
                  decoration: const InputDecoration(
                    labelText: 'Size Category',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SMALL', child: Text('Small')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                    DropdownMenuItem(value: 'LARGE', child: Text('Large')),
                  ],
                  onChanged: (val) => setState(() => _sizeCategory = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Colour and Coat
          TextFormField(
            controller: _colorCoatController,
            decoration: const InputDecoration(
              labelText: 'Colour & Coat (Optional)',
              hintText: 'e.g. Golden, short smooth coat',
            ),
          ),
          const SizedBox(height: 20),

          // Pedigree (Hidden if Companion Only)
          if (!isCompanionOnly) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedigree or Registration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Has official pedigree certificate / kennel club registry',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Switch(
                  value: _hasPedigree,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _hasPedigree = val),
                ),
              ],
            ),
            if (_hasPedigree) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isUploadingCert ? null : _pickPedigreeCert,
                icon: _isUploadingCert
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(
                  _pedigreeCertUrl != null
                      ? 'Certificate Attached (Tap to change)'
                      : 'Upload Certificate Image',
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Short Bio (Max 150 chars with live counter)
          TextFormField(
            controller: _bioController,
            maxLength: 150,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Short Bio (Optional)',
              hintText: 'Tell other pet parents what makes your pet special...',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Location (City/District only)
          InkWell(
            onTap: _showDistrictPicker,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Pet Location (City / District)',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ),
              child: Text(
                _selectedLocation ?? 'Select district',
                style: TextStyle(
                  color: _selectedLocation != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PurposeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PurposeOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
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
