import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/matching_repository.dart';
import '../../domain/entities/discovery_pet.dart';

enum SwipeDirection { left, right }
enum DiscoveryFilter { all, forYou }

class LikeSuccessEvent {
  final String eventId;
  final String petId;
  final String petName;
  final String? petImageUrl;
  final String? requestId;
  final bool matched;
  final String? matchId;

  const LikeSuccessEvent({
    required this.eventId,
    required this.petId,
    required this.petName,
    this.petImageUrl,
    this.requestId,
    required this.matched,
    this.matchId,
  });
}

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
  final DiscoveryFilter currentFilter;
  final String? forYouSpecies;
  final String? forYouNextCursor;
  final bool forYouHasMoreServer;
  final List<DiscoveryPet> forYouPets;
  final int forYouCurrentIndex;
  final bool isForYouLoading;
  final LikeSuccessEvent? likeSuccessEvent;

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
    this.currentFilter = DiscoveryFilter.all,
    this.forYouSpecies,
    this.forYouNextCursor,
    this.forYouHasMoreServer = false,
    this.forYouPets = const [],
    this.forYouCurrentIndex = 0,
    this.isForYouLoading = false,
    this.likeSuccessEvent,
  });

  DiscoveryPet? get currentPet {
    if (currentFilter == DiscoveryFilter.forYou) {
      return (forYouCurrentIndex >= 0 && forYouCurrentIndex < forYouPets.length)
          ? forYouPets[forYouCurrentIndex]
          : null;
    }
    return (currentIndex >= 0 && currentIndex < pets.length)
        ? pets[currentIndex]
        : null;
  }

  DiscoveryPet? get nextPet {
    if (currentFilter == DiscoveryFilter.forYou) {
      return (forYouCurrentIndex + 1 >= 0 && forYouCurrentIndex + 1 < forYouPets.length)
          ? forYouPets[forYouCurrentIndex + 1]
          : null;
    }
    return (currentIndex + 1 >= 0 && currentIndex + 1 < pets.length)
        ? pets[currentIndex + 1]
        : null;
  }

  bool get hasMore {
    if (currentFilter == DiscoveryFilter.forYou) {
      return forYouCurrentIndex < forYouPets.length;
    }
    return currentIndex < pets.length;
  }

  int get remainingCount {
    if (currentFilter == DiscoveryFilter.forYou) {
      return (forYouPets.length - forYouCurrentIndex).clamp(0, forYouPets.length);
    }
    return (pets.length - currentIndex).clamp(0, pets.length);
  }

  bool get isCurrentLoading => currentFilter == DiscoveryFilter.forYou ? isForYouLoading : isLoading;

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
    DiscoveryFilter? currentFilter,
    String? forYouSpecies,
    String? forYouNextCursor,
    bool? forYouHasMoreServer,
    List<DiscoveryPet>? forYouPets,
    int? forYouCurrentIndex,
    bool? isForYouLoading,
    LikeSuccessEvent? likeSuccessEvent,
    bool clearLikeEvent = false,
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
      currentFilter: currentFilter ?? this.currentFilter,
      forYouSpecies: forYouSpecies ?? this.forYouSpecies,
      forYouNextCursor: forYouNextCursor ?? this.forYouNextCursor,
      forYouHasMoreServer: forYouHasMoreServer ?? this.forYouHasMoreServer,
      forYouPets: forYouPets ?? this.forYouPets,
      forYouCurrentIndex: forYouCurrentIndex ?? this.forYouCurrentIndex,
      isForYouLoading: isForYouLoading ?? this.isForYouLoading,
      likeSuccessEvent: clearLikeEvent
          ? null
          : (likeSuccessEvent ?? this.likeSuccessEvent),
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
      currentFilter: DiscoveryFilter.all,
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

  Future<void> loadForYou(String petId, String species) async {
    state = state.copyWith(
      activePetId: petId,
      isForYouLoading: true,
      errorMessage: null,
      forYouCurrentIndex: 0,
      forYouPets: [],
      forYouSpecies: species,
      currentFilter: DiscoveryFilter.forYou,
    );

    try {
      final result = await _repository.getDiscover(
        petId: petId,
        limit: 10,
        species: species,
      );
      state = state.copyWith(
        isForYouLoading: false,
        forYouPets: result.pets,
        forYouNextCursor: result.nextCursor,
        forYouHasMoreServer: result.hasMore,
        errorMessage: null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Discovery] ❌ Failed to load For You feed for pet $petId (species: $species): $e',
        );
      }
      state = state.copyWith(
        isForYouLoading: false,
        errorMessage: 'Unable to load recommended pets. Please try again.',
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

  Future<void> _prefetchForYouNextPage() async {
    final petId = state.activePetId;
    final cursor = state.forYouNextCursor;
    final species = state.forYouSpecies;

    if (petId == null ||
        cursor == null ||
        !state.forYouHasMoreServer ||
        state.isForYouLoading) {
      return;
    }

    state = state.copyWith(isForYouLoading: true);

    try {
      final result = await _repository.getDiscover(
        petId: petId,
        cursor: cursor,
        limit: 10,
        species: species,
      );

      final combined = List<DiscoveryPet>.from(state.forYouPets)..addAll(result.pets);

      state = state.copyWith(
        isForYouLoading: false,
        forYouPets: combined,
        forYouNextCursor: result.nextCursor,
        forYouHasMoreServer: result.hasMore,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Discovery] ⚠️ For You prefetch error: $e');
      }
      state = state.copyWith(isForYouLoading: false);
    }
  }

  void setActivePet(String petId) {
    if (state.activePetId == petId && state.pets.isNotEmpty) return;
    loadInitial(petId);
  }

  void setFilter(DiscoveryFilter filter, {String? species}) {
    if (state.currentFilter == filter) return;
    
    if (filter == DiscoveryFilter.forYou) {
      final activePetId = state.activePetId;
      final targetSpecies = species ?? state.forYouSpecies;
      if (activePetId != null && targetSpecies != null) {
        loadForYou(activePetId, targetSpecies);
      }
    }
    state = state.copyWith(currentFilter: filter);
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
    if (state.currentFilter == DiscoveryFilter.forYou) {
      state = state.copyWith(
        forYouCurrentIndex: state.forYouCurrentIndex + 1,
        lastSwipedPetName: targetPet.petName,
        lastDirection: direction,
      );

      // 2. Prefetch next page when ~3 cards remain
      if (state.remainingCount <= 3 &&
          state.forYouHasMoreServer &&
          !state.isForYouLoading) {
        _prefetchForYouNextPage();
      }
    } else {
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
    }

    // 3. Fire-and-forget background write with single retry
    _sendBackgroundSwipe(
      petId: activePetId,
      targetPetId: targetPet.id,
      action: action,
      petName: targetPet.petName,
      petImageUrl: targetPet.petImageUrl.isNotEmpty
          ? targetPet.petImageUrl
          : null,
    );
  }

  Future<void> _sendBackgroundSwipe({
    required String petId,
    required String targetPetId,
    required String action,
    required String petName,
    String? petImageUrl,
  }) async {
    try {
      final result = await _repository.recordSwipe(
        petId: petId,
        targetPetId: targetPetId,
        action: action,
      );
      if (action == 'LIKE') {
        _emitLikeSuccess(
          petId: targetPetId,
          petName: petName,
          petImageUrl: petImageUrl,
          result: result,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Discovery] ⚠️ Background swipe attempt 1 failed for $petName: $e. Retrying once...',
        );
      }
      // Retry once
      try {
        final result = await _repository.recordSwipe(
          petId: petId,
          targetPetId: targetPetId,
          action: action,
        );
        if (action == 'LIKE') {
          _emitLikeSuccess(
            petId: targetPetId,
            petName: petName,
            petImageUrl: petImageUrl,
            result: result,
          );
        }
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

  void _emitLikeSuccess({
    required String petId,
    required String petName,
    String? petImageUrl,
    required Map<String, dynamic> result,
  }) {
    final matched = result['matched'] == true;
    final matchId = result['matchId'] as String?;
    final requestId = result['requestId'] as String?;
    state = state.copyWith(
      likeSuccessEvent: LikeSuccessEvent(
        eventId: '${petId}_${DateTime.now().microsecondsSinceEpoch}',
        petId: petId,
        petName: petName,
        petImageUrl: (result['targetPetImageUrl'] as String?) ?? petImageUrl,
        requestId: requestId,
        matched: matched,
        matchId: matchId,
      ),
    );
  }

  void clearLikeEvent() {
    state = state.copyWith(clearLikeEvent: true);
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

    if (state.currentFilter == DiscoveryFilter.forYou) {
      state = state.copyWith(
        isForYouLoading: true,
        errorMessage: null,
        forYouCurrentIndex: 0,
        forYouPets: [],
      );
    } else {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        currentIndex: 0,
        pets: [],
      );
    }

    try {
      await _repository.resetPassSwipes(petId: petId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Discovery] ⚠️ Failed to reset pass swipes for $petId: $e');
      }
    }

    if (state.currentFilter == DiscoveryFilter.forYou) {
      final species = state.forYouSpecies;
      if (species != null) {
        await loadForYou(petId, species);
      } else {
        await loadInitial(petId);
        state = state.copyWith(currentFilter: DiscoveryFilter.all);
      }
    } else {
      await loadInitial(petId);
    }
  }

  void retryLoad() {
    final petId = state.activePetId;
    if (petId != null) {
      if (state.currentFilter == DiscoveryFilter.forYou) {
        final species = state.forYouSpecies;
        if (species != null) {
          loadForYou(petId, species);
        } else {
          loadInitial(petId);
        }
      } else {
        loadInitial(petId);
      }
    }
  }
}

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  DiscoveryNotifier.new,
);
