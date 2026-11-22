import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/event_model.dart';
import '../models/mock_care_data.dart';
import '../models/vet_model.dart';

// --- EVENTS NOTIFIER ---

class EventsNotifier extends AsyncNotifier<List<PetEvent>> {
  ApiClient get _apiClient => ref.read(apiClientProvider);

  @override
  Future<List<PetEvent>> build() async {
    return _fetchEvents();
  }

  Future<List<PetEvent>> _fetchEvents() async {
    try {
      final res = await _apiClient.get('/events');
      final list = (res['events'] as List? ?? [])
          .map((e) => PetEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        MockCareData.events = list;
        return list;
      }
    } catch (_) {}
    return MockCareData.events;
  }

  Future<void> loadEvents() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchEvents());
  }

  Future<void> addEvent({
    required String title,
    required String category,
    required String fullDate,
    required String time,
    required String location,
    required String description,
  }) async {
    String dayName = 'DAY';
    String dayNum = '1';
    final parts = fullDate.split(' ');
    if (parts.length >= 2) {
      dayNum = parts[1].replaceAll(',', '');
    }

    try {
      final res = await _apiClient.post(
        '/events',
        body: {
          'title': title,
          'category': category,
          'dayName': dayName,
          'dayNum': dayNum,
          'fullDate': fullDate,
          'time': time,
          'location': location,
          'description': description,
          'attendeeCount': 0,
        },
      );

      final newEvent = PetEvent.fromJson(res['event'] as Map<String, dynamic>);
      MockCareData.events.insert(0, newEvent);
      final current = state.value ?? [];
      state = AsyncValue.data([newEvent, ...current]);
    } catch (_) {
      final fallbackEvent = PetEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        dayName: dayName,
        dayNum: dayNum,
        fullDate: fullDate,
        time: time,
        location: location,
        description: description,
        attendeeCount: 0,
      );
      MockCareData.events.insert(0, fallbackEvent);
      final current = state.value ?? [];
      state = AsyncValue.data([fallbackEvent, ...current]);
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _apiClient.delete('/events/$id');
    } catch (_) {}
    MockCareData.events.removeWhere((e) => e.id == id);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((e) => e.id != id).toList());
  }
}

final careEventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<PetEvent>>(
  EventsNotifier.new,
);

// --- VETS NOTIFIER ---

class VetsNotifier extends AsyncNotifier<List<Vet>> {
  ApiClient get _apiClient => ref.read(apiClientProvider);

  @override
  Future<List<Vet>> build() async {
    return _fetchVets();
  }

  Future<List<Vet>> _fetchVets() async {
    try {
      final res = await _apiClient.get('/veterinarians');
      final list = (res['veterinarians'] as List? ?? [])
          .map((v) => Vet.fromJson(v as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        MockCareData.vets = list;
        return list;
      }
    } catch (_) {}
    return MockCareData.vets;
  }

  Future<void> loadVets() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchVets());
  }

  Future<void> addVet({
    required String name,
    required String clinicName,
    required String specialty,
    required String address,
    required int fee,
  }) async {
    try {
      final res = await _apiClient.post(
        '/veterinarians',
        body: {
          'name': name,
          'clinicName': clinicName,
          'specialty': specialty,
          'address': address,
          'fee': fee,
          'rating': 5.0,
          'availableSlots': ['10:00 AM', '01:00 PM', '03:30 PM'],
          'isVerified': true,
          'isAcceptingBookings': true,
        },
      );

      final newVet = Vet.fromJson(res['veterinarian'] as Map<String, dynamic>);
      MockCareData.vets.insert(0, newVet);
      final current = state.value ?? [];
      state = AsyncValue.data([newVet, ...current]);
    } catch (_) {
      final fallbackVet = Vet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        clinicName: clinicName,
        specialty: specialty,
        address: address,
        rating: 5.0,
        fee: fee,
        availableSlots: ['10:00 AM', '01:00 PM', '03:30 PM'],
      );
      MockCareData.vets.insert(0, fallbackVet);
      final current = state.value ?? [];
      state = AsyncValue.data([fallbackVet, ...current]);
    }
  }

  Future<void> deleteVet(String id) async {
    try {
      await _apiClient.delete('/veterinarians/$id');
    } catch (_) {}
    MockCareData.vets.removeWhere((v) => v.id == id);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((v) => v.id != id).toList());
  }
}

final careVetsProvider =
    AsyncNotifierProvider<VetsNotifier, List<Vet>>(
  VetsNotifier.new,
);
