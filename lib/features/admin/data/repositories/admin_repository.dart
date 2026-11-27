import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/admin_audit_log_model.dart';
import '../models/admin_stats_model.dart';
import '../models/admin_user_model.dart';
import '../models/role_application_model.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminRepository(apiClient: apiClient);
});

class AdminRepository {
  final ApiClient apiClient;

  AdminRepository({required this.apiClient});

  Future<AdminStatsModel> getStats() async {
    final response = await apiClient.get('/admin/stats');
    return AdminStatsModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<AdminUserModel>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (role != null && role.isNotEmpty && role != 'ALL') 'role': role,
    };

    final response = await apiClient.get(
      '/admin/users',
      queryParameters: queryParams,
    );
    final usersList = (response['users'] as List? ?? [])
        .map((u) => AdminUserModel.fromJson(u as Map<String, dynamic>))
        .toList();
    return usersList;
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await apiClient.patch('/admin/users/$userId/role', body: {'role': role});
  }

  Future<void> updateUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    await apiClient.patch(
      '/admin/users/$userId/status',
      body: {'isActive': isActive},
    );
  }

  Future<List<RoleApplicationModel>> getApplications({
    int page = 1,
    int limit = 20,
    String status = 'PENDING',
    String? type,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty && type != 'ALL') 'type': type,
    };

    final response = await apiClient.get(
      '/admin/applications',
      queryParameters: queryParams,
    );
    final appsList = (response['applications'] as List? ?? [])
        .map((a) => RoleApplicationModel.fromJson(a as Map<String, dynamic>))
        .toList();
    return appsList;
  }

  Future<void> approveApplication(String applicationId) async {
    await apiClient.post('/admin/applications/$applicationId/approve');
  }

  Future<void> rejectApplication(String applicationId, {String? notes}) async {
    await apiClient.post(
      '/admin/applications/$applicationId/reject',
      body: {if (notes != null && notes.isNotEmpty) 'notes': notes},
    );
  }

  Future<List<AdminAuditLogModel>> getAuditLogs({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      '/admin/audit-logs',
      queryParameters: {'page': page, 'limit': limit},
    );
    final logsList = (response['logs'] as List? ?? [])
        .map((l) => AdminAuditLogModel.fromJson(l as Map<String, dynamic>))
        .toList();
    return logsList;
  }
}
