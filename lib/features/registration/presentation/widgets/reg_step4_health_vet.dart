import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/registration_service.dart';
import '../providers/registration_provider.dart';

class RegStep4HealthVet extends ConsumerStatefulWidget {
  const RegStep4HealthVet({super.key});

  @override
  ConsumerState<RegStep4HealthVet> createState() => RegStep4HealthVetState();
}

class RegStep4HealthVetState extends ConsumerState<RegStep4HealthVet> {
  final _formKey = GlobalKey<FormState>();

  String _vaccinationStatus = 'FULL'; // 'FULL', 'PARTIAL', 'NONE'
  DateTime? _rabiesDate;
  late TextEditingController _healthNotesController;
  String? _lastCheckup; // 'THIS_MONTH', 'THREE_MONTHS', 'SIX_MONTHS', 'UNKNOWN'

  final List<String> _vetRecordUrls = [];
  bool _isUploadingRecord = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final pet = ref.read(registrationProvider).pet;

    if (pet != null) {
      if (pet.vaccinationLevel.isNotEmpty) {
        _vaccinationStatus = pet.vaccinationLevel;
      }
      _rabiesDate = pet.rabiesVaccineDate;
      _healthNotesController = TextEditingController(text: pet.healthNotes ?? '');
      _lastCheckup = pet.lastCheckup;
      if (pet.vetRecordUrls.isNotEmpty) {
        _vetRecordUrls.addAll(pet.vetRecordUrls);
      }
    } else {
      _healthNotesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _healthNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickRabiesDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _rabiesDate ?? now,
      firstDate: DateTime(2010),
      lastDate: now,
      helpText: 'Select Rabies Vaccine Date',
    );

    if (picked != null) {
      setState(() => _rabiesDate = picked);
    }
  }

  Future<void> _pickVetRecord() async {
    if (_vetRecordUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 vet records allowed.')),
      );
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() => _isUploadingRecord = true);

      final asset = await ref.read(registrationServiceProvider).uploadPrivateImage(
            bytes: bytes,
            filename: 'vet_record_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

      if (mounted) {
        setState(() {
          _vetRecordUrls.add(asset.url);
          _isUploadingRecord = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingRecord = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload vet record: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = <String, dynamic>{
      'vaccinationLevel': _vaccinationStatus,
      'vaccinationStatus': _vaccinationStatus,
      if (_vaccinationStatus != 'NONE' && _rabiesDate != null)
        'rabiesVaccineDate': _rabiesDate!.toIso8601String(),
      if (_healthNotesController.text.trim().isNotEmpty)
        'healthNotes': _healthNotesController.text.trim(),
      if (_lastCheckup != null) 'lastCheckup': _lastCheckup,
      'vetRecordUrls': _vetRecordUrls,
      'profileStatus': 'COMPLETE',
    };

    await ref.read(registrationProvider.notifier).submitStep4AndComplete(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vaccination Status (Required)
          const Text(
            'Vaccination Status *',
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
                child: _VaccineOptionCard(
                  title: 'Fully vaccinated',
                  isSelected: _vaccinationStatus == 'FULL',
                  onTap: () => setState(() => _vaccinationStatus = 'FULL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VaccineOptionCard(
                  title: 'Partial',
                  isSelected: _vaccinationStatus == 'PARTIAL',
                  onTap: () => setState(() => _vaccinationStatus = 'PARTIAL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VaccineOptionCard(
                  title: 'None',
                  isSelected: _vaccinationStatus == 'NONE',
                  onTap: () => setState(() => _vaccinationStatus = 'NONE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rabies Vaccine Date (Show if not NONE)
          if (_vaccinationStatus != 'NONE') ...[
            InkWell(
              onTap: _pickRabiesDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Rabies Vaccine Date (Optional)',
                  prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                  suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                ),
                child: Text(
                  _rabiesDate != null
                      ? '${_rabiesDate!.year}-${_rabiesDate!.month.toString().padLeft(2, '0')}-${_rabiesDate!.day.toString().padLeft(2, '0')}'
                      : 'Select vaccination date',
                  style: TextStyle(
                    color: _rabiesDate != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Health conditions or allergies (Private)
          Row(
            children: [
              const Text(
                'Health Conditions / Allergies',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _healthNotesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Any recurring medical conditions, dietary allergies, or sensitivities...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // Last Vet Check-up (Single choice chips)
          const Text(
            'Last Vet Check-up',
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
            children: [
              _CheckupChip(
                label: 'This month',
                isSelected: _lastCheckup == 'THIS_MONTH',
                onSelected: () => setState(() => _lastCheckup = 'THIS_MONTH'),
              ),
              _CheckupChip(
                label: '3 months ago',
                isSelected: _lastCheckup == 'THREE_MONTHS',
                onSelected: () => setState(() => _lastCheckup = 'THREE_MONTHS'),
              ),
              _CheckupChip(
                label: '6 months ago',
                isSelected: _lastCheckup == 'SIX_MONTHS',
                onSelected: () => setState(() => _lastCheckup = 'SIX_MONTHS'),
              ),
              _CheckupChip(
                label: 'Not sure / Never',
                isSelected: _lastCheckup == 'UNKNOWN',
                onSelected: () => setState(() => _lastCheckup = 'UNKNOWN'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Vet records upload (up to 3 images, private)
          Row(
            children: [
              const Text(
                'Vet Records Upload (Up to 3)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Private - only you and your clinic vet can access this documentation.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._vetRecordUrls.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppNetworkImage(
                          imageUrl: entry.value,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _vetRecordUrls.removeAt(entry.key)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_vetRecordUrls.length < 3)
                InkWell(
                  onTap: _isUploadingRecord ? null : _pickVetRecord,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryLight,
                        width: 1.5,
                      ),
                    ),
                    child: _isUploadingRecord
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file_outlined, color: AppColors.primary),
                              SizedBox(height: 4),
                              Text(
                                'Upload',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _VaccineOptionCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _VaccineOptionCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CheckupChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _CheckupChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
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
      onSelected: (_) => onSelected(),
    );
  }
}
