import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../chat/data/models/all_connection_item.dart';
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
    String? initialMessage,
  }) async {
    final body = <String, dynamic>{
      'petId': petId,
      'targetPetId': targetPetId,
      'action': action,
    };
    if (initialMessage != null && initialMessage.trim().isNotEmpty) {
      body['initialMessage'] = initialMessage.trim();
    }

    final response = await _apiClient.post(
      '/swipes',
      body: body,
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

  Future<OutgoingRequestsResult> getOutgoingRequests({
    String? cursor,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final response = await _apiClient.get(
      '/requests/outgoing',
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return OutgoingRequestsResult.fromJson(response);
    }

    return const OutgoingRequestsResult(requests: [], hasMore: false);
  }

  Future<Map<String, dynamic>> updateIntroMessage({
    required String requestId,
    required String message,
  }) async {
    final response = await _apiClient.patch(
      '/requests/$requestId/message',
      body: {'message': message.trim()},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {'requestId': requestId, 'initialMessage': message.trim()};
  }

  Future<Map<String, dynamic>> cancelRequest(String requestId) async {
    final response = await _apiClient.post('/requests/$requestId/cancel');

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {'requestId': requestId, 'status': 'CANCELLED'};
  }

  Future<List<AllConnectionItem>> getAllConnections() async {
    final response = await _apiClient.get('/connections/all');
    if (response is Map<String, dynamic>) {
      final raw = response['items'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((item) => AllConnectionItem.fromJson(item))
          .toList();
    }
    return [];
  }
}

final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MatchingRepository(apiClient);
});
