import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/storage_service.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthRepository(apiClient: apiClient, storage: storage);
});

class AuthRepository {
  final ApiClient apiClient;
  final StorageService storage;

  AuthRepository({
    required this.apiClient,
    required this.storage,
  });

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String role = 'PET_OWNER',
  }) async {
    final response = await apiClient.post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'fullName': fullName,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
        'role': role,
      },
    );

    final token = response['token'] as String;
    final user = UserModel.fromJson(response['user'] as Map<String, dynamic>);

    await storage.saveAuthToken(token);
    await storage.saveUserData(userId: user.id, role: user.role);

    return user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final token = response['token'] as String;
    final user = UserModel.fromJson(response['user'] as Map<String, dynamic>);

    await storage.saveAuthToken(token);
    await storage.saveUserData(userId: user.id, role: user.role);

    return user;
  }

  Future<UserModel> getCurrentUser() async {
    final response = await apiClient.get('/auth/me');
    return UserModel.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await storage.clearAuth();
  }

  bool get isAuthenticated => storage.isAuthenticated;
}
