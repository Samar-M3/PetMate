import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/seller_application_model.dart';
import '../../data/models/seller_order_model.dart';
import '../../data/repositories/seller_repository.dart';

class SellerState {
  final bool isLoading;
  final bool isResubmitting;
  final String? errorMessage;
  final String? successMessage;
  final SellerStatusResponseModel? statusResponse;
  final SellerDashboardData? dashboardData;

  const SellerState({
    this.isLoading = false,
    this.isResubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.statusResponse,
    this.dashboardData,
  });

  SellerState copyWith({
    bool? isLoading,
    bool? isResubmitting,
    String? errorMessage,
    String? successMessage,
    SellerStatusResponseModel? statusResponse,
    SellerDashboardData? dashboardData,
    bool clearErrors = false,
    bool clearSuccess = false,
  }) {
    return SellerState(
      isLoading: isLoading ?? this.isLoading,
      isResubmitting: isResubmitting ?? this.isResubmitting,
      errorMessage: clearErrors ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      statusResponse: statusResponse ?? this.statusResponse,
      dashboardData: dashboardData ?? this.dashboardData,
    );
  }
}

class SellerNotifier extends Notifier<SellerState> {
  @override
  SellerState build() {
    return const SellerState();
  }

  SellerRepository get _repository => ref.read(sellerRepositoryProvider);
  FirebaseAuthService get _authService => ref.read(firebaseAuthServiceProvider);

  void clearMessages() {
    state = state.copyWith(clearErrors: true, clearSuccess: true);
  }

  /// Fetch seller status from backend
  Future<SellerStatusResponseModel?> loadSellerStatus() async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final status = await _repository.getSellerStatus();
      state = state.copyWith(isLoading: false, statusResponse: status);
      return status;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to check seller application status: $e',
      );
      return null;
    }
  }

  /// Register seller
  Future<bool> registerSeller(SellerRegistrationRequest request) async {
    state = state.copyWith(
      isLoading: true,
      clearErrors: true,
      clearSuccess: true,
    );
    try {
      final result = await _repository.registerSeller(request);

      // Sign in locally with Firebase Auth so that the user session is active
      try {
        await _authService.signInWithEmailAndPassword(
          email: request.email,
          password: request.password,
        );
        // Refresh auth state in auth notifier
        final user = _authService.currentUser;
        if (user != null) {
          await ref
              .read(authStateProvider.notifier)
              .loginWithEmail(request.email, request.password);
        }
      } catch (_) {
        // If automatic sign in is delayed, user can still log in via SellerLoginPage
      }

      final msg =
          result['message'] as String? ??
          'Seller registration submitted successfully. Your store is now pending admin review.';

      state = state.copyWith(isLoading: false, successMessage: msg);

      // Attempt to load seller status
      await loadSellerStatus();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Resubmit a rejected seller application
  Future<bool> resubmitApplication(Map<String, dynamic> updatedData) async {
    state = state.copyWith(
      isResubmitting: true,
      clearErrors: true,
      clearSuccess: true,
    );
    try {
      final updatedStore = await _repository.resubmitApplication(updatedData);
      state = state.copyWith(
        isResubmitting: false,
        successMessage: 'Application resubmitted successfully! It is now pending admin review.',
        statusResponse: SellerStatusResponseModel(
          hasStore: true,
          applicationStatus: 'PENDING',
          sellerName: state.statusResponse?.sellerName,
          email: state.statusResponse?.email,
          phoneNumber: state.statusResponse?.phoneNumber,
          isActive: state.statusResponse?.isActive ?? true,
          store: updatedStore,
        ),
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isResubmitting: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isResubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(
      isLoading: true,
      clearErrors: true,
      clearSuccess: true,
    );
    try {
      final msg = await _repository.requestPasswordReset(email);
      state = state.copyWith(isLoading: false, successMessage: msg);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to send password reset: $e',
      );
      return false;
    }
  }

  /// Load seller dashboard data (metrics, store info)
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final data = await _repository.getDashboard();
      state = state.copyWith(isLoading: false, dashboardData: data);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load seller dashboard: $e',
      );
    }
  }
}

final sellerProvider = NotifierProvider<SellerNotifier, SellerState>(() {
  return SellerNotifier();
});

class SellerOrdersState {
  final List<SellerCustomerOrder> orders;
  final bool isLoading;
  final String? error;

  const SellerOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  SellerOrdersState copyWith({
    List<SellerCustomerOrder>? orders,
    bool? isLoading,
    String? error,
  }) =>
      SellerOrdersState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class SellerOrdersNotifier extends Notifier<SellerOrdersState> {
  @override
  SellerOrdersState build() {
    Future.microtask(loadOrders);
    return const SellerOrdersState(isLoading: true);
  }

  SellerRepository get _repo => ref.read(sellerRepositoryProvider);

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getSellerOrders();
      state = state.copyWith(orders: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateStatus(String orderId, String status) async {
    try {
      final updated = await _repo.updateSellerOrderStatus(orderId, status);
      state = state.copyWith(
        orders: state.orders.map((o) => o.id == orderId ? updated : o).toList(),
      );
      ref.invalidate(sellerProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final sellerOrdersProvider =
    NotifierProvider<SellerOrdersNotifier, SellerOrdersState>(
  SellerOrdersNotifier.new,
);

final sellerOrderDetailProvider =
    FutureProvider.family<SellerCustomerOrder, String>((ref, orderId) async {
  final repo = ref.watch(sellerRepositoryProvider);
  return repo.getSellerOrderDetail(orderId);
});
