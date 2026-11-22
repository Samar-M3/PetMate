import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_stats_model.dart';
import '../../data/models/admin_user_model.dart';
import '../../data/models/role_application_model.dart';
import '../../data/repositories/admin_repository.dart';

// --- STATS PROVIDER ---

final adminStatsProvider =
    AsyncNotifierProvider<AdminStatsNotifier, AdminStatsModel>(
      AdminStatsNotifier.new,
    );

class AdminStatsNotifier extends AsyncNotifier<AdminStatsModel> {
  @override
  Future<AdminStatsModel> build() async {
    return _fetchStats();
  }

  Future<AdminStatsModel> _fetchStats() async {
    final repository = ref.read(adminRepositoryProvider);
    return repository.getStats();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchStats());
  }
}

// --- USERS MANAGEMENT PROVIDER ---

class AdminUsersState {
  final bool isLoading;
  final String? errorMessage;
  final List<AdminUserModel> users;
  final String search;
  final String
  roleFilter; // 'ALL', 'PET_OWNER', 'SELLER', 'VETERINARIAN', 'ADMIN'

  const AdminUsersState({
    this.isLoading = false,
    this.errorMessage,
    this.users = const [],
    this.search = '',
    this.roleFilter = 'ALL',
  });

  AdminUsersState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<AdminUserModel>? users,
    String? search,
    String? roleFilter,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      users: users ?? this.users,
      search: search ?? this.search,
      roleFilter: roleFilter ?? this.roleFilter,
    );
  }
}

final adminUsersProvider =
    NotifierProvider<AdminUsersNotifier, AdminUsersState>(
      AdminUsersNotifier.new,
    );

class AdminUsersNotifier extends Notifier<AdminUsersState> {
  @override
  AdminUsersState build() {
    Future.microtask(() => loadUsers());
    return const AdminUsersState(isLoading: true);
  }

  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  Future<void> loadUsers({String? search, String? roleFilter}) async {
    final querySearch = search ?? state.search;
    final queryRole = roleFilter ?? state.roleFilter;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      search: querySearch,
      roleFilter: queryRole,
    );

    try {
      final users = await _repository.getUsers(
        search: querySearch.trim().isEmpty ? null : querySearch.trim(),
        role: queryRole == 'ALL' ? null : queryRole,
      );
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> changeRole(String userId, String newRole) async {
    await _repository.updateUserRole(userId: userId, role: newRole);
    // Reload users and stats
    await loadUsers();
    ref.read(adminStatsProvider.notifier).refresh();
  }

  Future<void> toggleUserStatus(String userId, bool newStatus) async {
    await _repository.updateUserStatus(userId: userId, isActive: newStatus);
    await loadUsers();
    ref.read(adminStatsProvider.notifier).refresh();
  }
}

// --- APPLICATIONS PROVIDER ---

class AdminApplicationsState {
  final bool isLoading;
  final String? errorMessage;
  final List<RoleApplicationModel> applications;
  final String statusFilter; // 'PENDING', 'APPROVED', 'REJECTED'
  final String typeFilter; // 'ALL', 'SELLER', 'VETERINARIAN'

  const AdminApplicationsState({
    this.isLoading = false,
    this.errorMessage,
    this.applications = const [],
    this.statusFilter = 'PENDING',
    this.typeFilter = 'ALL',
  });

  AdminApplicationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<RoleApplicationModel>? applications,
    String? statusFilter,
    String? typeFilter,
  }) {
    return AdminApplicationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      applications: applications ?? this.applications,
      statusFilter: statusFilter ?? this.statusFilter,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

final adminApplicationsProvider =
    NotifierProvider<AdminApplicationsNotifier, AdminApplicationsState>(
      AdminApplicationsNotifier.new,
    );

class AdminApplicationsNotifier extends Notifier<AdminApplicationsState> {
  @override
  AdminApplicationsState build() {
    Future.microtask(() => loadApplications());
    return const AdminApplicationsState(isLoading: true);
  }

  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  Future<void> loadApplications({String? status, String? type}) async {
    final s = status ?? state.statusFilter;
    final t = type ?? state.typeFilter;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      statusFilter: s,
      typeFilter: t,
    );

    try {
      final apps = await _repository.getApplications(
        status: s,
        type: t == 'ALL' ? null : t,
      );
      state = state.copyWith(isLoading: false, applications: apps);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> approve(String applicationId) async {
    await _repository.approveApplication(applicationId);
    await loadApplications();
    ref.read(adminStatsProvider.notifier).refresh();
  }

  Future<void> reject(String applicationId, {String? notes}) async {
    await _repository.rejectApplication(applicationId, notes: notes);
    await loadApplications();
    ref.read(adminStatsProvider.notifier).refresh();
  }
}
