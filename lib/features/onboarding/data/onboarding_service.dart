import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/api_client.dart';
import 'onboarding_models.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(apiClient: ref.watch(apiClientProvider));
});

class OnboardingService {
  final ApiClient apiClient;

  OnboardingService({required this.apiClient});

  Future<OwnerProfileData> getMyProfile() async {
    final response = await apiClient.get('/profile/me');
    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final profile = data['profile'] as Map<String, dynamic>? ?? data;
      return OwnerProfileData.fromJson(profile);
    }
    throw ApiException(message: 'Failed to load profile');
  }

  Future<OwnerProfileData> saveStep1({
    required String displayName,
    String? avatarUrl,
    String? avatarPublicId,
    required String city,
    required String district,
  }) async {
    final response = await apiClient.put(
      '/profile/me',
      body: {
        'displayName': displayName,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
        if (avatarPublicId != null && avatarPublicId.isNotEmpty)
          'avatarPublicId': avatarPublicId,
        'city': city,
        'district': district,
      },
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final profile = data['profile'] as Map<String, dynamic>? ?? data;
      return OwnerProfileData.fromJson(profile);
    }
    throw ApiException(message: 'Failed to save profile');
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
        'name': name,
        'species': species,
        if (speciesOther != null && speciesOther.isNotEmpty)
          'speciesOther': speciesOther,
        'breed': breed,
        'gender': gender,
        'ageYears': ageYears,
        'ageMonths': ageMonths,
        'photos': photos.map((p) => p.toJson()).toList(),
      },
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final pet = data['pet'] as Map<String, dynamic>? ?? data;
      return OnboardingPetData.fromJson(pet);
    }
    throw ApiException(message: 'Failed to create pet profile');
  }

  Future<OnboardingPetData> patchPet(
    String petId,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.patch('/pets/$petId', body: payload);
    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final pet = data['pet'] as Map<String, dynamic>? ?? data;
      return OnboardingPetData.fromJson(pet);
    }
    throw ApiException(message: 'Failed to update pet profile');
  }

  Future<void> completeOnboarding({String? petId}) async {
    await apiClient.post(
      '/profile/complete',
      body: {
        if (petId != null && petId.isNotEmpty) 'petId': petId,
      },
    );
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
      filename: filename,
      fieldName: 'image',
      fields: {'folder': folder},
    );
    return _parseUpload(response);
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
      filename: filename,
      fieldName: 'image',
      fields: {'folder': 'vet_records'},
    );
    return _parseUpload(response);
  }

  UploadedAsset _parseUpload(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final url = (data['url'] ?? data['imageUrl'])?.toString() ?? '';
      final publicId =
          (data['publicId'] ?? data['imagePublicId'])?.toString() ?? '';
      if (url.isNotEmpty) {
        return UploadedAsset(url: url, publicId: publicId);
      }
    }
    throw ApiException(message: 'Failed to upload image. Please try again.');
  }
}
