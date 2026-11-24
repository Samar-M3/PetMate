import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_preference_model.dart';
import 'api_client.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRepository(apiClient);
});

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? appVersion,
    String locale = 'en',
  }) async {
    await _apiClient.post(
      '/api/v1/devices',
      body: {
        'token': token,
        'platform': platform,
        'appVersion': appVersion,
        'locale': locale,
      },
    );
  }

  Future<void> deleteDeviceToken(String token) async {
    await _apiClient.delete('/api/v1/devices/$token');
  }

  Future<NotificationPreferenceModel> getPreferences() async {
    final response = await _apiClient.get('/api/v1/notifications/preferences');
    if (response is Map<String, dynamic> && response['data'] != null) {
      return NotificationPreferenceModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    }
    return const NotificationPreferenceModel();
  }

  Future<NotificationPreferenceModel> updatePreferences(
    NotificationPreferenceModel preferences,
  ) async {
    final response = await _apiClient.patch(
      '/api/v1/notifications/preferences',
      body: preferences.toJson(),
    );
    if (response is Map<String, dynamic> && response['data'] != null) {
      return NotificationPreferenceModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    }
    return preferences;
  }
}
