import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/onboarding_models.dart';
import '../../data/onboarding_service.dart';

class OnboardingState {
  final int currentStep;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final OwnerProfileData? profile;
  final OnboardingPetData? pet;
  final bool isCompleted;

  const OnboardingState({
    this.currentStep = 1,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.profile,
    this.pet,
    this.isCompleted = false,
  });

  OnboardingState copyWith({
    int? currentStep,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    OwnerProfileData? profile,
    OnboardingPetData? pet,
    bool? isCompleted,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      profile: profile ?? this.profile,
      pet: pet ?? this.pet,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    Future.microtask(loadInitialState);
    return const OnboardingState(isLoading: true);
  }

  OnboardingService get _service => ref.read(onboardingServiceProvider);

  Future<void> loadInitialState() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.getMyProfile();
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        pet: profile.draftPet,
        currentStep: profile.onboardingStep.clamp(1, 4),
        isCompleted: profile.onboardingCompleted,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
      );
    }
  }

  void goToStep(int step) {
    state = state.copyWith(
      currentStep: step.clamp(1, 4),
      clearError: true,
    );
  }

  void goBack() {
    if (state.currentStep > 1) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        clearError: true,
      );
    }
  }

  Future<UploadedAsset> uploadPublicImage({
    File? file,
    Uint8List? bytes,
    String? filename,
    String folder = 'pets',
  }) {
    return _service.uploadImage(
      file: file,
      bytes: bytes,
      filename: filename,
      folder: folder,
    );
  }

  Future<UploadedAsset> uploadPrivateImage({
    File? file,
    Uint8List? bytes,
    String? filename,
  }) {
    return _service.uploadPrivateImage(
      file: file,
      bytes: bytes,
      filename: filename,
    );
  }

  Future<bool> saveStep1({
    required String displayName,
    String? avatarUrl,
    String? avatarPublicId,
    required String city,
    required String district,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updatedProfile = await _service.saveStep1(
        displayName: displayName,
        avatarUrl: avatarUrl,
        avatarPublicId: avatarPublicId,
        city: city,
        district: district,
      );
      state = state.copyWith(
        isSaving: false,
        profile: updatedProfile,
        currentStep: 2,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> saveStep2({
    required String name,
    required String species,
    String? speciesOther,
    required String breed,
    required String gender,
    required int ageYears,
    required int ageMonths,
    required List<PetPhotoItem> photos,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      OnboardingPetData savedPet;
      if (state.pet != null && state.pet!.id.isNotEmpty) {
        savedPet = await _service.patchPet(state.pet!.id, {
          'name': name,
          'species': species,
          'speciesOther': speciesOther ?? '',
          'breed': breed,
          'gender': gender,
          'ageYears': ageYears,
          'ageMonths': ageMonths,
          'photos': photos.map((p) => p.toJson()).toList(),
          'onboardingStep': 3,
        });
      } else {
        savedPet = await _service.createPetStep2(
          name: name,
          species: species,
          speciesOther: speciesOther,
          breed: breed,
          gender: gender,
          ageYears: ageYears,
          ageMonths: ageMonths,
          photos: photos,
        );
      }
      state = state.copyWith(
        isSaving: false,
        pet: savedPet,
        currentStep: 3,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> saveStep3(Map<String, dynamic> payload) async {
    final petId = state.pet?.id;
    if (petId == null || petId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Pet profile missing. Please complete Step 2 first.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updatedPet = await _service.patchPet(petId, {
        ...payload,
        'onboardingStep': 4,
      });
      state = state.copyWith(
        isSaving: false,
        pet: updatedPet,
        currentStep: 4,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> skipStep3() {
    return saveStep3({
      'purpose': 'COMPANION',
      'isNeutered': false,
    });
  }

  Future<bool> saveStep4AndComplete(Map<String, dynamic>? payload) async {
    final petId = state.pet?.id;
    if (petId == null || petId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Pet profile missing. Please complete Step 2 first.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      if (payload != null && payload.isNotEmpty) {
        final updatedPet = await _service.patchPet(petId, payload);
        state = state.copyWith(pet: updatedPet);
      }
      await _service.completeOnboarding(petId: petId);
      await ref.read(authStateProvider.notifier).refreshUser();
      state = state.copyWith(isSaving: false, isCompleted: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network')) {
      return 'No internet connection. Please check your network and tap Retry.';
    }
    return msg;
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
