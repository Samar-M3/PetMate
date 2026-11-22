import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/activation_summary_model.dart';
import '../../data/repositories/pets_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PetsActivationState {
  final bool isLoading;
  final ActivationSummaryModel? summary;
  final String? errorMessage;
  final String? actionMessage;

  const PetsActivationState({
    this.isLoading = false,
    this.summary,
    this.errorMessage,
    this.actionMessage,
  });

  PetsActivationState copyWith({
    bool? isLoading,
    ActivationSummaryModel? summary,
    String? errorMessage,
    String? actionMessage,
  }) {
    return PetsActivationState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }
}

class PetsActivationNotifier extends Notifier<PetsActivationState> {
  @override
  PetsActivationState build() {
    return const PetsActivationState();
  }

  PetsRepository get _repository => ref.read(petsRepositoryProvider);

  Future<void> loadSummary() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final summary = await _repository.getActivationSummary();
      state = state.copyWith(isLoading: false, summary: summary);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<Map<String, dynamic>> toggleActivation({
    required String petId,
    required bool active,
    String? deactivatePetId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.setPetActivation(
        petId: petId,
        active: active,
        deactivatePetId: deactivatePetId,
      );
      await loadSummary();
      // Refresh auth state so the pet list (and isActive flags) update immediately
      await ref.read(authStateProvider.notifier).refreshUserProfile();
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkout({
    required int quantity,
    required String gateway,
  }) async {
    return await _repository.initiateCheckout(
      quantity: quantity,
      gateway: gateway,
    );
  }

  Future<Map<String, dynamic>> verify({
    required String paymentId,
    String? transactionId,
  }) async {
    final result = await _repository.verifyPayment(
      paymentId: paymentId,
      transactionId: transactionId,
    );
    await loadSummary();
    return result;
  }
}

final petsActivationProvider =
    NotifierProvider<PetsActivationNotifier, PetsActivationState>(
      PetsActivationNotifier.new,
    );
