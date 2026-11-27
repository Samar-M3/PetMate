import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/api_client.dart';
import '../models/seller_application_model.dart';
import '../models/seller_order_model.dart';

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SellerRepository(apiClient: apiClient);
});

class SellerRegistrationRequest {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String confirmPassword;
  final String storeName;
  final String businessType; // 'INDIVIDUAL' or 'REGISTERED_BUSINESS'
  final String? description;
  final String businessAddress;
  final String city;
  final String province;
  final String postalCode;
  final String? registrationDocUrl;
  final String? identityDocUrl;
  final bool termsAccepted;
  final bool privacyAccepted;

  const SellerRegistrationRequest({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.confirmPassword,
    required this.storeName,
    required this.businessType,
    this.description,
    required this.businessAddress,
    required this.city,
    required this.province,
    required this.postalCode,
    this.registrationDocUrl,
    this.identityDocUrl,
    required this.termsAccepted,
    required this.privacyAccepted,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      'confirmPassword': confirmPassword,
      'storeName': storeName,
      'businessType': businessType,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'businessAddress': businessAddress,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      if (registrationDocUrl != null && registrationDocUrl!.isNotEmpty)
        'registrationDocUrl': registrationDocUrl,
      if (identityDocUrl != null && identityDocUrl!.isNotEmpty)
        'identityDocUrl': identityDocUrl,
      'termsAccepted': termsAccepted,
      'privacyAccepted': privacyAccepted,
    };
  }
}

class SellerRepository {
  final ApiClient apiClient;

  SellerRepository({required this.apiClient});

  /// Register as a new seller
  Future<Map<String, dynamic>> registerSeller(
    SellerRegistrationRequest request,
  ) async {
    final response = await apiClient.post(
      '/sellers/register',
      body: request.toJson(),
    );

    if (response is Map<String, dynamic>) {
      if (response['data'] != null &&
          response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }
      return response;
    }
    throw ApiException(message: 'Invalid response from server');
  }

  /// Get status of current logged in seller's application
  Future<SellerStatusResponseModel> getSellerStatus() async {
    final response = await apiClient.get('/sellers/status');

    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      return SellerStatusResponseModel.fromJson(data);
    }
    throw ApiException(message: 'Failed to parse seller status');
  }

  /// Resubmit a rejected seller application with updated details
  Future<SellerStoreModel> resubmitApplication(
    Map<String, dynamic> updatedData,
  ) async {
    final response = await apiClient.put(
      '/sellers/resubmit',
      body: updatedData,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      return SellerStoreModel.fromJson(data);
    }
    throw ApiException(message: 'Failed to parse resubmission response');
  }

  /// Request a password reset email link
  Future<String> requestPasswordReset(String email) async {
    final response = await apiClient.post(
      '/sellers/forgot-password',
      body: {'email': email},
    );

    if (response is Map<String, dynamic>) {
      return response['message'] as String? ??
          'Password reset link sent successfully if the email exists.';
    }
    return 'Password reset link sent if account exists.';
  }

  /// Fetch seller dashboard metrics and store details
  Future<SellerDashboardData> getDashboard() async {
    final response = await apiClient.get('/sellers/dashboard');

    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      return SellerDashboardData.fromJson(data);
    }
    throw ApiException(message: 'Failed to retrieve seller dashboard');
  }

  /// Fetch orders placed for this seller's products
  Future<List<SellerCustomerOrder>> getSellerOrders() async {
    final response = await apiClient.get('/sellers/orders');
    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final items = (data['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SellerCustomerOrder.fromJson)
          .toList();
      return items;
    }
    return [];
  }

  /// Fetch details of a single seller order
  Future<SellerCustomerOrder> getSellerOrderDetail(String orderId) async {
    final response = await apiClient.get('/sellers/orders/$orderId');
    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final orderMap = data['order'] as Map<String, dynamic>? ?? data;
      return SellerCustomerOrder.fromJson(orderMap);
    }
    throw ApiException(message: 'Failed to retrieve seller order details');
  }

  /// Update the status of a seller order
  Future<SellerCustomerOrder> updateSellerOrderStatus(
    String orderId,
    String status,
  ) async {
    final response = await apiClient.patch(
      '/sellers/orders/$orderId/status',
      body: {'status': status},
    );
    if (response is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final orderMap = data['order'] as Map<String, dynamic>? ?? data;
      return SellerCustomerOrder.fromJson(orderMap);
    }
    throw ApiException(message: 'Failed to update order status');
  }
}
