import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient: apiClient);
});

class OnboardingStatusResult {
  final bool isInitialized;
  final String? userId;
  final bool onboardingCompleted;
  final bool hasPets;
  final bool hasProfile;
  final String nextStep; // "INITIALIZE", "PET_INFO", "OWNER_INFO", "COMPLETED"
  final int onboardingStep; // 1–4, persisted per step completion

  OnboardingStatusResult({
    required this.isInitialized,
    this.userId,
    required this.onboardingCompleted,
    required this.hasPets,
    required this.hasProfile,
    required this.nextStep,
    this.onboardingStep = 1,
  });

  factory OnboardingStatusResult.fromJson(Map<String, dynamic> json) {
    return OnboardingStatusResult(
      isInitialized: json['isInitialized'] as bool? ?? false,
      userId: json['userId'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      hasPets: json['hasPets'] as bool? ?? false,
      hasProfile: json['hasProfile'] as bool? ?? false,
      nextStep: json['nextStep'] as String? ?? 'PET_INFO',
      onboardingStep: json['onboardingStep'] as int? ?? 1,
    );
  }
}

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<UserModel> initializeUser({String? phoneNumber}) async {
    final response = await apiClient.post(
      '/users/initialize',
      body: {
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );

    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<UserModel> getMe() async {
    final response = await apiClient.get('/users/me');
    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<UserModel> completeInitialVeterinarianPassword(
    String newPassword,
  ) async {
    final response = await apiClient.post(
      '/users/me/initial-password',
      body: {'newPassword': newPassword},
    );
    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<OnboardingStatusResult> getOnboardingStatus() async {
    final response = await apiClient.get('/users/onboarding-status');
    return OnboardingStatusResult.fromJson(response as Map<String, dynamic>);
  }

  Future<UserModel> updateOwnerProfile({
    required String fullName,
    String? profilePictureUrl,
    String? imageUrl,
    String? imagePublicId,
    required String location,
    String? area,
    String? bio,
    String? phoneNumber,
    bool onboardingCompleted = true,
  }) async {
    final effectiveUrl = imageUrl ?? profilePictureUrl;
    final response = await apiClient.put(
      '/users/me',
      body: {
        'fullName': fullName,
        'imageUrl': ?effectiveUrl,
        'profilePictureUrl': ?effectiveUrl,
        'imagePublicId': ?imagePublicId,
        'location': location,
        if (area != null && area.isNotEmpty) 'area': area,
        if (bio != null && bio.isNotEmpty) 'bio': bio,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
        'onboardingCompleted': onboardingCompleted,
      },
    );

    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> uploadUserAvatar(File file) async {
    final response = await apiClient.postMultipart(
      '/users/me/avatar',
      file: file,
      fieldName: 'image',
    );

    return response as Map<String, dynamic>;
  }

  Future<PetModel> createPet({
    required String name,
    String? profilePictureUrl,
    String? imageUrl,
    String? imagePublicId,
    required String animalType,
    required String breed,
    required String gender,
    required DateTime dateOfBirth,
    String? color,
    List<String> personality = const [],
    required String vaccinationStatus,
    String? allergies,
    String? description,
  }) async {
    final effectiveUrl = imageUrl ?? profilePictureUrl;
    final response = await apiClient.post(
      '/pets',
      body: {
        'name': name,
        'imageUrl': ?effectiveUrl,
        'profilePictureUrl': ?effectiveUrl,
        'imagePublicId': ?imagePublicId,
        'animalType': animalType,
        'breed': breed,
        'gender': gender,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        if (color != null && color.isNotEmpty) 'color': color,
        'personality': personality,
        'vaccinationStatus': vaccinationStatus,
        if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );

    return PetModel.fromJson(response['pet'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> uploadPetImage(String petId, File file) async {
    final response = await apiClient.postMultipart(
      '/pets/$petId/image',
      file: file,
      fieldName: 'image',
    );

    return response as Map<String, dynamic>;
  }

  Future<List<PetModel>> getPets() async {
    final response = await apiClient.get('/pets');
    final list = response['pets'] as List;
    return list
        .map((item) => PetModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePet(String petId) async {
    await apiClient.delete('/pets/$petId');
  }

  Future<void> deletePetImage(String petId) async {
    await apiClient.delete('/pets/$petId/image');
  }
}
