import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/data/repositories/matching_repository.dart';
import '../../data/models/all_connection_item.dart';

class OutgoingRequestsState {
  final List<OutgoingRequestModel> requests;
  final bool isLoading;
  final Set<String> actionLoadingIds;
  final String? errorMessage;

  const OutgoingRequestsState({
    this.requests = const [],
    this.isLoading = false,
    this.actionLoadingIds = const {},
    this.errorMessage,
  });

  OutgoingRequestsState copyWith({
    List<OutgoingRequestModel>? requests,
    bool? isLoading,
    Set<String>? actionLoadingIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OutgoingRequestsState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      actionLoadingIds: actionLoadingIds ?? this.actionLoadingIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class OutgoingRequestsNotifier extends Notifier<OutgoingRequestsState> {
  MatchingRepository get _repository => ref.read(matchingRepositoryProvider);

  @override
  OutgoingRequestsState build() => const OutgoingRequestsState();

  Future<void> loadOutgoingRequests({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.getOutgoingRequests(limit: 50);
      state = state.copyWith(
        requests: result.requests,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load liked pets: $e',
      );
    }
  }

  Future<bool> updateIntroMessage({
    required String requestId,
    required String message,
  }) async {
    if (state.actionLoadingIds.contains(requestId)) return false;

    final loading = Set<String>.from(state.actionLoadingIds)..add(requestId);
    state = state.copyWith(actionLoadingIds: loading);

    try {
      await _repository.updateIntroMessage(
        requestId: requestId,
        message: message,
      );
      final now = DateTime.now();
      final updated = state.requests.map((r) {
        if (r.id != requestId) return r;
        return r.copyWith(
          initialMessage: message.trim(),
          initialMessageAt: now,
        );
      }).toList();

      final done = Set<String>.from(state.actionLoadingIds)..remove(requestId);
      state = state.copyWith(requests: updated, actionLoadingIds: done);
      ref.invalidate(allConnectionsProvider);
      return true;
    } catch (_) {
      final done = Set<String>.from(state.actionLoadingIds)..remove(requestId);
      state = state.copyWith(actionLoadingIds: done);
      rethrow;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    if (state.actionLoadingIds.contains(requestId)) return false;

    final loading = Set<String>.from(state.actionLoadingIds)..add(requestId);
    state = state.copyWith(actionLoadingIds: loading);

    try {
      await _repository.cancelRequest(requestId);
      final updated = state.requests.map((r) {
        if (r.id != requestId) return r;
        return r.copyWith(
          status: 'CANCELLED',
          cancelledAt: DateTime.now(),
        );
      }).toList();

      final done = Set<String>.from(state.actionLoadingIds)..remove(requestId);
      state = state.copyWith(requests: updated, actionLoadingIds: done);
      ref.invalidate(allConnectionsProvider);
      return true;
    } catch (_) {
      final done = Set<String>.from(state.actionLoadingIds)..remove(requestId);
      state = state.copyWith(actionLoadingIds: done);
      rethrow;
    }
  }
}

final outgoingRequestsProvider =
    NotifierProvider<OutgoingRequestsNotifier, OutgoingRequestsState>(
      OutgoingRequestsNotifier.new,
    );

final allConnectionsProvider = FutureProvider<List<AllConnectionItem>>((
  ref,
) async {
  final repo = ref.watch(matchingRepositoryProvider);
  return repo.getAllConnections();
});
