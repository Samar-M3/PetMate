import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/matching_repository.dart';

class RequestsState {
  final List<ConnectionRequestModel> requests;
  final int pendingCount;
  final bool isLoading;
  final Set<String> actionLoadingIds;
  final String? errorMessage;

  const RequestsState({
    this.requests = const [],
    this.pendingCount = 0,
    this.isLoading = false,
    this.actionLoadingIds = const {},
    this.errorMessage,
  });

  RequestsState copyWith({
    List<ConnectionRequestModel>? requests,
    int? pendingCount,
    bool? isLoading,
    Set<String>? actionLoadingIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RequestsState(
      requests: requests ?? this.requests,
      pendingCount: pendingCount ?? this.pendingCount,
      isLoading: isLoading ?? this.isLoading,
      actionLoadingIds: actionLoadingIds ?? this.actionLoadingIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RequestsNotifier extends Notifier<RequestsState> {
  MatchingRepository get _repository => ref.read(matchingRepositoryProvider);

  @override
  RequestsState build() {
    return const RequestsState();
  }

  Future<void> loadRequests({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _repository.getIncomingRequests(limit: 50);
      state = state.copyWith(
        requests: result.requests,
        pendingCount: result.pendingCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load requests: $e',
      );
    }
  }

  Future<void> accept(
    String requestId, {
    required void Function(Map<String, dynamic> result) onAccepted,
    void Function(String error)? onError,
  }) async {
    if (state.actionLoadingIds.contains(requestId)) return;

    final updatedActionIds = Set<String>.from(state.actionLoadingIds)..add(requestId);
    state = state.copyWith(actionLoadingIds: updatedActionIds);

    try {
      final result = await _repository.acceptRequest(requestId);

      // Successfully accepted: remove from list and decrement pendingCount
      final updatedRequests = state.requests.where((r) => r.id != requestId).toList();
      final newPendingCount = max(0, state.pendingCount - 1);
      final finalActionIds = Set<String>.from(state.actionLoadingIds)..remove(requestId);

      state = state.copyWith(
        requests: updatedRequests,
        pendingCount: newPendingCount,
        actionLoadingIds: finalActionIds,
      );

      // Invoke callback: UI can show snackbar / navigate
      // // PART 3 HOOK: navigate to chat window
      onAccepted(result);
    } catch (e) {
      final finalActionIds = Set<String>.from(state.actionLoadingIds)..remove(requestId);
      final errMsg = e.toString();

      // If already responded to (409), also remove from the list
      if (errMsg.contains('409') || errMsg.contains('already been')) {
        final updatedRequests = state.requests.where((r) => r.id != requestId).toList();
        final newPendingCount = max(0, state.pendingCount - 1);
        state = state.copyWith(
          requests: updatedRequests,
          pendingCount: newPendingCount,
          actionLoadingIds: finalActionIds,
        );
      } else {
        state = state.copyWith(actionLoadingIds: finalActionIds);
      }

      onError?.call('Unable to accept request: $e');
    }
  }

  Future<void> reject(
    String requestId, {
    void Function()? onRejected,
    void Function(String error)? onError,
  }) async {
    if (state.actionLoadingIds.contains(requestId)) return;

    final updatedActionIds = Set<String>.from(state.actionLoadingIds)..add(requestId);
    state = state.copyWith(actionLoadingIds: updatedActionIds);

    try {
      await _repository.rejectRequest(requestId);

      // Successfully rejected: remove from list and decrement pendingCount
      final updatedRequests = state.requests.where((r) => r.id != requestId).toList();
      final newPendingCount = max(0, state.pendingCount - 1);
      final finalActionIds = Set<String>.from(state.actionLoadingIds)..remove(requestId);

      state = state.copyWith(
        requests: updatedRequests,
        pendingCount: newPendingCount,
        actionLoadingIds: finalActionIds,
      );

      onRejected?.call();
    } catch (e) {
      final finalActionIds = Set<String>.from(state.actionLoadingIds)..remove(requestId);
      final errMsg = e.toString();

      // If already responded to (409), also remove from list
      if (errMsg.contains('409') || errMsg.contains('already been')) {
        final updatedRequests = state.requests.where((r) => r.id != requestId).toList();
        final newPendingCount = max(0, state.pendingCount - 1);
        state = state.copyWith(
          requests: updatedRequests,
          pendingCount: newPendingCount,
          actionLoadingIds: finalActionIds,
        );
      } else {
        state = state.copyWith(actionLoadingIds: finalActionIds);
      }

      onError?.call('Unable to reject request: $e');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final requestsProvider = NotifierProvider<RequestsNotifier, RequestsState>(RequestsNotifier.new);
