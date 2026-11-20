import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/activation_summary_model.dart';

class PetsRepository {
  final ApiClient _apiClient;

  PetsRepository(this._apiClient);

  Future<ActivationSummaryModel> getActivationSummary() async {
    final response = await _apiClient.get('/pets/activation/summary');
    if (response is Map<String, dynamic>) {
      return ActivationSummaryModel.fromJson(response);
    }
    throw Exception('Invalid response format for activation summary');
  }

  Future<Map<String, dynamic>> setPetActivation({
    required String petId,
    required bool active,
    String? deactivatePetId,
  }) async {
    final body = <String, dynamic>{
      'active': active,
      ...?deactivatePetId != null ? {'deactivatePetId': deactivatePetId} : null,
    };
    final response = await _apiClient.post(
      '/pets/$petId/activation',
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'status': 'success'};
  }

  Future<Map<String, dynamic>> initiateCheckout({
    required int quantity,
    required String gateway,
  }) async {
    final response = await _apiClient.post(
      '/active-slots/checkout',
      body: {'quantity': quantity, 'gateway': gateway},
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw Exception('Invalid checkout initiation response');
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    String? transactionId,
  }) async {
    final response = await _apiClient.post(
      '/active-slots/verify',
      body: {
        'paymentId': paymentId,
        ...?transactionId != null ? {'transactionId': transactionId} : null,
      },
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw Exception('Invalid verification response');
  }
}

final petsRepositoryProvider = Provider<PetsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PetsRepository(apiClient);
});
