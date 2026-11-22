import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../pets/domain/entities/public_pet_profile.dart';
import '../../domain/entities/public_user_profile.dart';

final publicProfileRepositoryProvider =
    Provider<PublicProfileRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return PublicProfileRepository(client);
});

class PublicProfileRepository {
  final ApiClient _client;

  PublicProfileRepository(this._client);

  Future<PublicPetProfile> getPublicPet(String petId) async {
    final response = await _client.get('/pets/$petId/public');
    if (response is Map<String, dynamic>) {
      final petData = response['pet'] ?? response;
      if (petData is Map<String, dynamic>) {
        return PublicPetProfile.fromJson(petData);
      }
    }
    throw Exception('Failed to parse public pet profile');
  }

  Future<PublicUserProfile> getPublicUser(String userId) async {
    final response = await _client.get('/users/$userId/public');
    if (response is Map<String, dynamic>) {
      final userData = response['user'] ?? response;
      if (userData is Map<String, dynamic>) {
        return PublicUserProfile.fromJson(userData);
      }
    }
    throw Exception('Failed to parse public user profile');
  }
}

final publicPetProvider =
    FutureProvider.family<PublicPetProfile, String>((ref, petId) async {
  return ref.watch(publicProfileRepositoryProvider).getPublicPet(petId);
});

final publicUserProvider =
    FutureProvider.family<PublicUserProfile, String>((ref, userId) async {
  return ref.watch(publicProfileRepositoryProvider).getPublicUser(userId);
});
