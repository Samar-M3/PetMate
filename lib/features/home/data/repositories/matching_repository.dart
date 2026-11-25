import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/connection_request_model.dart';
import '../models/discovery_pet_model.dart';

export '../models/connection_request_model.dart';

class DiscoverFeedResult {
  final List<DiscoveryPetModel> pets;
  final String? nextCursor;
  final bool hasMore;

  const DiscoverFeedResult({
    required this.pets,
    this.nextCursor,
    required this.hasMore,
  });

  factory DiscoverFeedResult.fromJson(Map<String, dynamic> json) {
    final rawPets = json['pets'] as List<dynamic>? ?? [];
    final pets = rawPets
        .whereType<Map<String, dynamic>>()
        .map((p) => DiscoveryPetModel.fromJson(p))
        .toList();

    return DiscoverFeedResult(
      pets: pets,
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class MatchingRepository {
  final ApiClient _apiClient;

  MatchingRepository(this._apiClient);

  Future<DiscoverFeedResult> getDiscover({
    required String petId,
    String? cursor,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{'petId': petId, 'limit': limit};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final response = await _apiClient.get(
      '/discover',
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return DiscoverFeedResult.fromJson(response);
    }

    return const DiscoverFeedResult(pets: [], hasMore: false);
  }

  Future<Map<String, dynamic>> recordSwipe({
    required String petId,
    required String targetPetId,
    required String action, // "LIKE" | "PASS"
  }) async {
    final response = await _apiClient.post(
      '/swipes',
      body: {'petId': petId, 'targetPetId': targetPetId, 'action': action},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {'status': 'recorded'};
  }

  Future<void> resetPassSwipes({required String petId}) async {
    await _apiClient.post(
      '/swipes/reset-passes',
      body: {'petId': petId},
    );
  }

  Future<IncomingRequestsResult> getIncomingRequests({
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final response = await _apiClient.get(
      '/requests/incoming',
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return IncomingRequestsResult.fromJson(response);
    }

    return const IncomingRequestsResult(
      requests: [],
      hasMore: false,
      pendingCount: 0,
    );
  }

  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    final response = await _apiClient.post('/requests/$requestId/accept');

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {'status': 'ACCEPTED'};
  }

  Future<Map<String, dynamic>> rejectRequest(String requestId) async {
    final response = await _apiClient.post('/requests/$requestId/reject');

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {'status': 'REJECTED'};
  }
}

final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MatchingRepository(apiClient);
});
