import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../onboarding/data/onboarding_models.dart';

final registrationServiceProvider = Provider<RegistrationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RegistrationService(apiClient: apiClient);
});

class RegistrationService {
  final ApiClient apiClient;

  RegistrationService({required this.apiClient});

  Future<Map<String, dynamic>> registerPetOwner({
    required String email,
    required String password,
    required String fullName,
    String? displayName,
    required String phoneNumber,
    required String city,
    required String district,
    String? avatarUrl,
    String? avatarPublicId,
    required bool termsAccepted,
  }) async {
    final response = await apiClient.post(
      '/auth/register',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'fullName': fullName.trim(),
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'city': city.trim(),
        'district': district.trim(),
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
        if (avatarPublicId != null && avatarPublicId.isNotEmpty)
          'avatarPublicId': avatarPublicId,
        'termsAccepted': termsAccepted,
        'role': 'PET_OWNER',
      },
    );

    return response as Map<String, dynamic>;
  }

  Future<UploadedAsset> uploadImage({
    File? file,
    Uint8List? bytes,
    String? filename,
    String folder = 'pets',
  }) async {
    final response = await apiClient.postMultipart(
      '/uploads/image',
      file: file,
      bytes: bytes,
      filename: filename ?? (file != null ? file.path.split(Platform.pathSeparator).last : 'upload.jpg'),
      fieldName: 'image',
      fields: {'folder': folder},
    );

    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;

    return UploadedAsset(
      url: (data['url'] ?? data['imageUrl'] ?? '') as String,
      publicId: (data['publicId'] ?? data['imagePublicId'] ?? '') as String,
    );
  }

  Future<UploadedAsset> uploadPrivateImage({
    File? file,
    Uint8List? bytes,
    String? filename,
  }) async {
    final response = await apiClient.postMultipart(
      '/uploads/private-image',
      file: file,
      bytes: bytes,
      filename: filename ?? 'vet_record.jpg',
      fieldName: 'image',
      fields: {'folder': 'vet_records'},
    );

    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;

    return UploadedAsset(
      url: (data['url'] ?? data['imageUrl'] ?? '') as String,
      publicId: (data['publicId'] ?? data['imagePublicId'] ?? '') as String,
    );
  }

  Future<OwnerProfileData> getMyProfile() async {
    final response = await apiClient.get('/profile/me');
    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;

    return OwnerProfileData.fromJson(data);
  }

  Future<OnboardingPetData> createPetStep2({
    required String name,
    required String species,
    String? speciesOther,
    required String breed,
    required String gender,
    required int ageYears,
    required int ageMonths,
    required List<PetPhotoItem> photos,
  }) async {
    final response = await apiClient.post(
      '/pets',
      body: {
        'name': name.trim(),
        'species': species.toUpperCase(),
        if (speciesOther != null && speciesOther.trim().isNotEmpty)
          'speciesOther': speciesOther.trim(),
        'breed': breed.trim(),
        'gender': gender.toUpperCase(),
        'ageYears': ageYears,
        'ageMonths': ageMonths,
        'photos': photos.map((p) => p.toJson()).toList(),
        'onboardingStep': 3,
      },
    );

    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;

    final petData = data.containsKey('pet') ? data['pet'] as Map<String, dynamic> : data;
    return OnboardingPetData.fromJson(petData);
  }

  Future<OnboardingPetData> patchPet(String petId, Map<String, dynamic> payload) async {
    final response = await apiClient.patch('/pets/$petId', body: payload);
    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;

    final petData = data.containsKey('pet') ? data['pet'] as Map<String, dynamic> : data;
    return OnboardingPetData.fromJson(petData);
  }

  Future<Map<String, dynamic>> completeRegistration({String? petId}) async {
    final response = await apiClient.post(
      '/profile/complete',
      body: {
        if (petId != null) 'petId': petId,
      },
    );

    return (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
  }
}
