import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_scaffold.dart';

class Step4HealthVet extends ConsumerStatefulWidget {
  const Step4HealthVet({super.key});

  @override
  ConsumerState<Step4HealthVet> createState() => _Step4HealthVetState();
}

class _Step4HealthVetState extends ConsumerState<Step4HealthVet> {
  final _healthNotesController = TextEditingController();

  String _vaccinationStatus = 'NONE';
  DateTime? _rabiesVaccineDate;
  String? _lastCheckup;
  final List<String> _vetRecordUrls = [];
  bool _isUploadingRecord = false;
  String? _uploadError;
  bool _initialized = false;

  static const List<Map<String, String>> _vaccinationOptions = [
    {'value': 'FULL', 'label': 'Fully vaccinated'},
    {'value': 'PARTIAL', 'label': 'Partial'},
    {'value': 'NONE', 'label': 'None'},
  ];

  static const List<Map<String, String>> _checkupOptions = [
    {'value': 'THIS_MONTH', 'label': 'This month'},
    {'value': 'THREE_MONTHS', 'label': '3 months ago'},
    {'value': 'SIX_MONTHS', 'label': '6 months ago'},
    {'value': 'UNKNOWN', 'label': 'Not sure or never'},
  ];

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
      if (['FULL', 'PARTIAL', 'NONE'].contains(pet.vaccinationStatus)) {
        _vaccinationStatus = pet.vaccinationStatus;
      }
      _rabiesVaccineDate = pet.rabiesVaccineDate;
      _healthNotesController.text = pet.healthNotes ?? '';
      _lastCheckup = pet.lastCheckup;
      _vetRecordUrls
        ..clear()
        ..addAll(pet.vetRecordUrls);
    }
    if (mounted) setState(() {});
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
      initialDate: _rabiesVaccineDate ?? now,
      firstDate: DateTime(now.year - 25),
      lastDate: now, // Cannot be in the future
    );
    if (picked != null) {
      setState(() => _rabiesVaccineDate = picked);
    }
  }

  Future<void> _pickVetRecord() async {
    if (_vetRecordUrls.length >= 3) {
      setState(() => _uploadError = 'You can upload up to 3 vet records.');
      return;
    }

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
          _uploadError = 'Invalid file type. Only JPG, PNG, and WebP images are allowed.';
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _uploadError = 'Image exceeds 5 MB limit.';
        });
        return;
      }

      setState(() {
        _isUploadingRecord = true;
        _uploadError = null;
      });

      final asset =
          await ref.read(onboardingProvider.notifier).uploadPrivateImage(
                file: kIsWeb ? null : File(picked.path),
                bytes: bytes,
                filename: picked.name,
              );

      setState(() {
        _vetRecordUrls.add(asset.url);
        _isUploadingRecord = false;
      });
    } catch (_) {
      setState(() {
        _isUploadingRecord = false;
        _uploadError = 'Failed to upload vet record. Check your connection and retry.';
      });
    }
  }

  Future<void> _finish({required bool skipped}) async {
    if (_isUploadingRecord) return;

    final payload = skipped
        ? {'vaccinationStatus': 'NONE'}
        : {
            'vaccinationStatus': _vaccinationStatus,
            if (_vaccinationStatus != 'NONE' && _rabiesVaccineDate != null)
              'rabiesVaccineDate': _rabiesVaccineDate!.toIso8601String(),
            if (_healthNotesController.text.trim().isNotEmpty)
              'healthNotes': _healthNotesController.text.trim(),
            if (_lastCheckup != null) 'lastCheckup': _lastCheckup,
            'vetRecordUrls': _vetRecordUrls,
          };

    final ok = await ref
        .read(onboardingProvider.notifier)
        .saveStep4AndComplete(payload);

    if (ok && mounted) {
      await _showFinishDialog();
    }
  }

  Future<void> _showFinishDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              'You’re all set!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your profile and pet profile are ready.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/');
                },
                child: const Text('Go to Home'),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                context.go('/my-pets');
              },
              child: const Text(
                'Add another pet later from your profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      step: 4,
      title: 'Health & vet care',
      subtitle: 'Keep your pet’s vaccination and medical records handy.',
      nextLabel: 'Get Started',
      isSaving: state.isSaving || _isUploadingRecord,
      errorMessage: _uploadError ?? state.errorMessage,
      onBack: () => ref.read(onboardingProvider.notifier).goBack(),
      onSkip: () => _finish(skipped: true),
      onRetry: () => _finish(skipped: false),
      onNext: () => _finish(skipped: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vaccination Status (Required)
          const Text(
            'Vaccination status *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._vaccinationOptions.map((opt) {
            final selected = _vaccinationStatus == opt['value'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _vaccinationStatus = opt['value']!),
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
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color:
                            selected ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        opt['label']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Rabies Vaccine Date (only if status != NONE)
          if (_vaccinationStatus != 'NONE') ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickRabiesDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Rabies vaccine date (optional)',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _rabiesVaccineDate != null
                      ? DateFormat('MMM d, yyyy').format(_rabiesVaccineDate!)
                      : 'Select vaccination date',
                  style: TextStyle(
                    color: _rabiesVaccineDate != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Health conditions or allergies (Private)
          Row(
            children: [
              const Text(
                'Health conditions or allergies',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _healthNotesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Optional: food allergies, medications, past surgery...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Last vet check-up (Single choice)
          const Text(
            'Last vet check-up (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _checkupOptions.map((opt) {
              final selected = _lastCheckup == opt['value'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: selected,
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                backgroundColor: Colors.white,
                onSelected: (val) {
                  setState(() {
                    _lastCheckup = val ? opt['value'] : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Vet records upload (up to 3 private images)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vet records (optional, up to 3)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_vetRecordUrls.length}/3',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Private - only you and your vet can see this',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
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
                        onTap: () =>
                            setState(() => _vetRecordUrls.removeAt(entry.key)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: _isUploadingRecord
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file_outlined,
                                  color: AppColors.primary),
                              SizedBox(height: 4),
                              Text(
                                'Add record',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Add another pet later from your profile',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
