import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/matching_repository.dart';
import '../../domain/entities/discovery_pet.dart';

enum SwipeDirection { left, right }

class DiscoveryState {
  final List<DiscoveryPet> pets;
  final int currentIndex;
  final bool isLoading;
  final bool isPrefetching;
  final String? activePetId;
  final String? nextCursor;
  final bool hasMoreServer;
  final String? errorMessage;
  final String? snackbarMessage;
  final String? lastSwipedPetName;
  final SwipeDirection? lastDirection;

  const DiscoveryState({
    this.pets = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isPrefetching = false,
    this.activePetId,
    this.nextCursor,
    this.hasMoreServer = false,
    this.errorMessage,
    this.snackbarMessage,
    this.lastSwipedPetName,
    this.lastDirection,
  });

  DiscoveryPet? get currentPet =>
      (currentIndex >= 0 && currentIndex < pets.length)
      ? pets[currentIndex]
      : null;

  DiscoveryPet? get nextPet =>
      (currentIndex + 1 >= 0 && currentIndex + 1 < pets.length)
      ? pets[currentIndex + 1]
      : null;

  bool get hasMore => currentIndex < pets.length;

  int get remainingCount => (pets.length - currentIndex).clamp(0, pets.length);

  DiscoveryState copyWith({
    List<DiscoveryPet>? pets,
    int? currentIndex,
    bool? isLoading,
    bool? isPrefetching,
    String? activePetId,
    String? nextCursor,
    bool? hasMoreServer,
    String? errorMessage,
    String? snackbarMessage,
    bool clearSnackbar = false,
    String? lastSwipedPetName,
    SwipeDirection? lastDirection,
  }) {
    return DiscoveryState(
      pets: pets ?? this.pets,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isPrefetching: isPrefetching ?? this.isPrefetching,
      activePetId: activePetId ?? this.activePetId,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMoreServer: hasMoreServer ?? this.hasMoreServer,
      errorMessage: errorMessage,
      snackbarMessage: clearSnackbar
          ? null
          : (snackbarMessage ?? this.snackbarMessage),
      lastSwipedPetName: lastSwipedPetName ?? this.lastSwipedPetName,
      lastDirection: lastDirection ?? this.lastDirection,
    );
  }
}

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  bool _isSwipeLocked = false;

  MatchingRepository get _repository => ref.read(matchingRepositoryProvider);

  @override
  DiscoveryState build() {
    return const DiscoveryState(pets: [], currentIndex: 0, isLoading: false);
  }

  Future<void> loadInitial(String petId) async {
    state = state.copyWith(
      activePetId: petId,
      isLoading: true,
      errorMessage: null,
      currentIndex: 0,
      pets: [],
    );

    try {
      final result = await _repository.getDiscover(petId: petId, limit: 10);
      state = state.copyWith(
        isLoading: false,
        pets: result.pets,
        nextCursor: result.nextCursor,
        hasMoreServer: result.hasMore,
        errorMessage: null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Discovery] ❌ Failed to load initial feed for pet $petId: $e',
        );
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load pet recommendations. Please try again.',
      );
    }
  }

  Future<void> _prefetchNextPage() async {
    final petId = state.activePetId;
    final cursor = state.nextCursor;

    if (petId == null ||
        cursor == null ||
        !state.hasMoreServer ||
        state.isPrefetching) {
      return;
    }

    state = state.copyWith(isPrefetching: true);

    try {
      final result = await _repository.getDiscover(
        petId: petId,
        cursor: cursor,
        limit: 10,
      );

      final combined = List<DiscoveryPet>.from(state.pets)..addAll(result.pets);

      state = state.copyWith(
        isPrefetching: false,
        pets: combined,
        nextCursor: result.nextCursor,
        hasMoreServer: result.hasMore,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Discovery] ⚠️ Prefetch error: $e');
      }
      state = state.copyWith(isPrefetching: false);
    }
  }

  void setActivePet(String petId) {
    if (state.activePetId == petId && state.pets.isNotEmpty) return;
    loadInitial(petId);
  }

  void swipeRight() {
    _handleSwipe(SwipeDirection.right, 'LIKE');
  }

  void swipeLeft() {
    _handleSwipe(SwipeDirection.left, 'PASS');
  }

  void _handleSwipe(SwipeDirection direction, String action) {
    if (_isSwipeLocked) return;
    if (!state.hasMore) return;

    final targetPet = state.currentPet;
    final activePetId = state.activePetId;
    if (targetPet == null || activePetId == null) return;

    _isSwipeLocked = true;
    Future.delayed(const Duration(milliseconds: 260), () {
      _isSwipeLocked = false;
    });

    if (kDebugMode) {
      debugPrint(
        '[Discovery] ${direction == SwipeDirection.right ? "❤️ Liked" : "✖️ Passed"} pet: ${targetPet.petName} (ID: ${targetPet.id})',
      );
    }

    // 1. Optimistic UI update immediately
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      lastSwipedPetName: targetPet.petName,
      lastDirection: direction,
    );

    // 2. Prefetch next page when ~3 cards remain
    if (state.remainingCount <= 3 &&
        state.hasMoreServer &&
        !state.isPrefetching) {
      _prefetchNextPage();
    }

    // 3. Fire-and-forget background write with single retry
    _sendBackgroundSwipe(
      petId: activePetId,
      targetPetId: targetPet.id,
      action: action,
      petName: targetPet.petName,
    );
  }

  Future<void> _sendBackgroundSwipe({
    required String petId,
    required String targetPetId,
    required String action,
    required String petName,
  }) async {
    try {
      await _repository.recordSwipe(
        petId: petId,
        targetPetId: targetPetId,
        action: action,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Discovery] ⚠️ Background swipe attempt 1 failed for $petName: $e. Retrying once...',
        );
      }
      // Retry once
      try {
        await _repository.recordSwipe(
          petId: petId,
          targetPetId: targetPetId,
          action: action,
        );
      } catch (retryError) {
        if (kDebugMode) {
          debugPrint(
            '[Discovery] ❌ Background swipe attempt 2 failed: $retryError',
          );
        }
        state = state.copyWith(
          snackbarMessage:
              'Failed to record swipe for $petName. Please check your connection.',
        );
      }
    }
  }

  void clearSnackbar() {
    state = state.copyWith(clearSnackbar: true);
  }

  void clearActivePet() {
    state = const DiscoveryState(pets: [], currentIndex: 0, isLoading: false);
  }

  Future<void> resetDeck() async {
    final petId = state.activePetId;
    if (petId == null) {
      state = const DiscoveryState(pets: [], currentIndex: 0, isLoading: false);
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      currentIndex: 0,
      pets: [],
    );

    try {
      await _repository.resetPassSwipes(petId: petId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Discovery] ⚠️ Failed to reset pass swipes for $petId: $e');
      }
    }

    await loadInitial(petId);
  }

  void retryLoad() {
    final petId = state.activePetId;
    if (petId != null) {
      loadInitial(petId);
    }
  }
}

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  DiscoveryNotifier.new,
);
