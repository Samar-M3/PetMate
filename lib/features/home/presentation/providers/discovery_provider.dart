import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/discovery_pet_model.dart';
import '../../domain/entities/discovery_pet.dart';

enum SwipeDirection { left, right }

class DiscoveryState {
  final List<DiscoveryPet> pets;
  final int currentIndex;
  final bool isLoading;
  final String? lastSwipedPetName;
  final SwipeDirection? lastDirection;

  const DiscoveryState({
    this.pets = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.lastSwipedPetName,
    this.lastDirection,
  });

  DiscoveryPet? get currentPet =>
      (currentIndex >= 0 && currentIndex < pets.length) ? pets[currentIndex] : null;

  DiscoveryPet? get nextPet =>
      (currentIndex + 1 >= 0 && currentIndex + 1 < pets.length) ? pets[currentIndex + 1] : null;

  bool get hasMore => currentIndex < pets.length;

  int get remainingCount => (pets.length - currentIndex).clamp(0, pets.length);

  DiscoveryState copyWith({
    List<DiscoveryPet>? pets,
    int? currentIndex,
    bool? isLoading,
    String? lastSwipedPetName,
    SwipeDirection? lastDirection,
  }) {
    return DiscoveryState(
      pets: pets ?? this.pets,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      lastSwipedPetName: lastSwipedPetName,
      lastDirection: lastDirection,
    );
  }
}

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() {
    return DiscoveryState(
      pets: DiscoveryPetModel.curatedMockPets,
      currentIndex: 0,
      isLoading: false,
    );
  }

  void swipeRight() {
    if (!state.hasMore) return;
    final pet = state.currentPet;
    debugPrint('[Discovery] ❤️ Liked pet: ${pet?.petName} (ID: ${pet?.id})');
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      lastSwipedPetName: pet?.petName,
      lastDirection: SwipeDirection.right,
    );
  }

  void swipeLeft() {
    if (!state.hasMore) return;
    final pet = state.currentPet;
    debugPrint('[Discovery] ✖️ Passed pet: ${pet?.petName} (ID: ${pet?.id})');
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      lastSwipedPetName: pet?.petName,
      lastDirection: SwipeDirection.left,
    );
  }

  void resetDeck() {
    debugPrint('[Discovery] 🔄 Resetting discovery deck');
    state = DiscoveryState(
      pets: DiscoveryPetModel.curatedMockPets,
      currentIndex: 0,
      isLoading: false,
    );
  }
}

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(DiscoveryNotifier.new);
