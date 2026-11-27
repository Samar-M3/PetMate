import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/nearby_owner_model.dart';

final nearbyServiceProvider = Provider<NearbyService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NearbyService(apiClient);
});

class NearbyService {
  final ApiClient _apiClient;

  NearbyService(this._apiClient);

  Future<NearbyCurrentUserLocation> updateLocation({
    required double latitude,
    required double longitude,
    String? area,
    bool? locationEnabled,
  }) async {
    final response = await _apiClient.post(
      '/owners/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (area != null && area.trim().isNotEmpty) 'area': area.trim(),
        // ignore: use_null_aware_elements
        if (locationEnabled != null) 'locationEnabled': locationEnabled,
      },
    );

    // _handleResponse already unwraps decoded['data'], so response IS the data map.
    final data = response as Map<String, dynamic>? ?? {};
    return NearbyCurrentUserLocation.fromJson(data);
  }

  Future<NearbyOwnersResponse> fetchNearbyOwners({
    int radius = 10,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/owners/nearby',
      queryParameters: {
        'radius': '$radius',
        'page': '$page',
        'limit': '$limit',
      },
    );

    // _handleResponse already unwraps decoded['data'], so response IS the data map.
    final data = response as Map<String, dynamic>? ?? {};
    return NearbyOwnersResponse.fromJson(data);
  }

  Future<bool> updateLocationVisibility(bool locationEnabled) async {
    final response = await _apiClient.patch(
      '/owners/location-visibility',
      body: {'locationEnabled': locationEnabled},
    );

    // _handleResponse already unwraps decoded['data'], so response IS the data map.
    final data = response as Map<String, dynamic>? ?? {};
    return data['locationEnabled'] as bool? ?? locationEnabled;
  }
}
