import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/data/onboarding_models.dart';
import '../../data/registration_service.dart';

class RegistrationState {
  final int currentStep;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final bool canResumeLogin;

  // Step 1 Form Data (preserved across steps)
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String confirmPassword;
  final String city;
  final String district;
  final bool termsAccepted;
  final File? avatarFile;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final String? avatarPublicId;

  // Authenticated Profile & Draft Pet Data
  final String? authToken;
  final OwnerProfileData? profile;
  final OnboardingPetData? pet;
  final bool isCompleted;

  const RegistrationState({
    this.currentStep = 1,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.canResumeLogin = false,
    this.fullName = '',
    this.email = '',
    this.phoneNumber = '',
    this.password = '',
    this.confirmPassword = '',
    this.city = '',
    this.district = '',
    this.termsAccepted = false,
    this.avatarFile,
    this.avatarBytes,
    this.avatarUrl,
    this.avatarPublicId,
    this.authToken,
    this.profile,
    this.pet,
    this.isCompleted = false,
  });

  RegistrationState copyWith({
    int? currentStep,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    bool? canResumeLogin,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    String? confirmPassword,
    String? city,
    String? district,
    bool? termsAccepted,
    File? avatarFile,
    Uint8List? avatarBytes,
    String? avatarUrl,
    String? avatarPublicId,
    String? authToken,
    OwnerProfileData? profile,
    OnboardingPetData? pet,
    bool? isCompleted,
  }) {
    return RegistrationState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canResumeLogin: canResumeLogin ?? this.canResumeLogin,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      city: city ?? this.city,
      district: district ?? this.district,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      avatarFile: avatarFile ?? this.avatarFile,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarPublicId: avatarPublicId ?? this.avatarPublicId,
      authToken: authToken ?? this.authToken,
      profile: profile ?? this.profile,
      pet: pet ?? this.pet,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class RegistrationNotifier extends Notifier<RegistrationState> {
  @override
  RegistrationState build() {
    return const RegistrationState();
  }

  RegistrationService get _service => ref.read(registrationServiceProvider);
  StorageService get _storage => ref.read(storageServiceProvider);

  void updateStep1Data({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    String? confirmPassword,
    String? city,
    String? district,
    bool? termsAccepted,
    File? avatarFile,
    Uint8List? avatarBytes,
    String? avatarUrl,
  }) {
    state = state.copyWith(
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
      confirmPassword: confirmPassword,
      city: city,
      district: district,
      termsAccepted: termsAccepted,
      avatarFile: avatarFile,
      avatarBytes: avatarBytes,
      avatarUrl: avatarUrl,
      clearError: true,
    );
  }

  Future<void> loadSavedProgress() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.getMyProfile();
      state = state.copyWith(
        isLoading: false,
        profile: profile,
        pet: profile.draftPet,
        fullName: profile.displayName.isNotEmpty ? profile.displayName : state.fullName,
        city: profile.city.isNotEmpty ? profile.city : state.city,
        district: profile.district.isNotEmpty ? profile.district : state.district,
        avatarUrl: profile.avatarUrl ?? state.avatarUrl,
        currentStep: profile.onboardingStep.clamp(2, 4),
        isCompleted: profile.registrationCompleted,
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

  Future<bool> submitStep1({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String city,
    required String district,
    required bool termsAccepted,
    File? avatarFile,
    Uint8List? avatarBytes,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true, canResumeLogin: false);
    try {
      // 1. If avatar was selected, we can upload it after registration with the new token
      final regResponse = await _service.registerPetOwner(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        city: city,
        district: district,
        termsAccepted: termsAccepted,
      );

      final token = (regResponse['data']?['token'] ?? regResponse['token']) as String?;
      if (token != null && token.isNotEmpty) {
        await _storage.saveAuthToken(token);
      }

      // 2. Upload avatar if selected
      String? uploadedUrl;
      String? uploadedPublicId;
      if (avatarFile != null || avatarBytes != null) {
        try {
          final asset = await _service.uploadImage(
            file: avatarFile,
            bytes: avatarBytes,
            folder: 'users',
          );
          uploadedUrl = asset.url;
          uploadedPublicId = asset.publicId;
        } catch (_) {
          // Non-blocking: avatar upload failure shouldn't stop flow
        }
      }

      final profileData = OwnerProfileData(
        id: regResponse['data']?['profile']?['id'] ?? '',
        userId: regResponse['data']?['user']?['id'] ?? '',
        email: email,
        role: 'PET_OWNER',
        displayName: fullName,
        avatarUrl: uploadedUrl,
        city: city,
        district: district,
        onboardingStep: 2,
        onboardingCompleted: false,
        registrationCompleted: false,
      );

      // Refresh auth provider state
      try {
        await ref.read(authStateProvider.notifier).refreshUser();
      } catch (_) {}

      state = state.copyWith(
        isSaving: false,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        city: city,
        district: district,
        termsAccepted: termsAccepted,
        avatarFile: avatarFile,
        avatarBytes: avatarBytes,
        avatarUrl: uploadedUrl,
        avatarPublicId: uploadedPublicId,
        authToken: token,
        profile: profileData,
        currentStep: 2,
      );

      return true;
    } catch (e) {
      final msg = _friendlyError(e);
      final canResume = msg.contains('incomplete registration') ||
          e.toString().contains('INCOMPLETE_REGISTRATION');
      state = state.copyWith(
        isSaving: false,
        errorMessage: msg,
        canResumeLogin: canResume,
      );
      return false;
    }
  }

  Future<bool> submitStep2({
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

  Future<bool> submitStep3(Map<String, dynamic> payload) async {
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
    return submitStep3({
      'purpose': 'COMPANION',
      'isNeutered': false,
    });
  }

  Future<bool> submitStep4AndComplete(Map<String, dynamic>? payload) async {
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

      await _service.completeRegistration(petId: petId);

      // Refresh auth profile in Riverpod
      try {
        await ref.read(authStateProvider.notifier).refreshUser();
      } catch (_) {}

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

final registrationProvider =
    NotifierProvider<RegistrationNotifier, RegistrationState>(
  RegistrationNotifier.new,
);
