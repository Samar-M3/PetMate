import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../models/appointment_model.dart';
import '../models/event_model.dart';
import '../models/vet_model.dart';

final String _apiBase = AppConfig.baseUrl;

Future<Map<String, String>> _getHeaders() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

/// Safely extracts a List from your backend's { success, data: { ... } } wrapper
List<dynamic> _extractList(dynamic decoded, List<String> possibleKeys) {
  if (decoded is List) return decoded;
  if (decoded is Map<String, dynamic>) {
    final inner = decoded['data'] ?? decoded;
    if (inner is List) return inner;
    if (inner is Map<String, dynamic>) {
      for (final key in possibleKeys) {
        if (inner[key] is List) return inner[key] as List;
      }
      for (final val in inner.values) {
        if (val is List) return val;
      }
    }
  }
  return [];
}

// ==========================================
// 1. EVENTS
// ==========================================
final careEventsProvider =
    AsyncNotifierProvider<CareEventsNotifier, List<PetEvent>>(
        CareEventsNotifier.new);

class CareEventsNotifier extends AsyncNotifier<List<PetEvent>> {
  /// Keys ("<eventId>:rsvp") of requests in flight, so double taps are ignored.
  final Set<String> _pending = {};

  @override
  Future<List<PetEvent>> build() => _fetchEvents();

  /// Full reload with a loading state (used by the admin shell).
  Future<void> loadEvents() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchEvents);
  }

  /// Pull-to-refresh: keeps the current list on screen and throws on failure.
  Future<void> refresh() async {
    state = AsyncData(await _fetchEvents());
  }

  Future<List<PetEvent>> _fetchEvents() async {
    final data = await CareApi.get('/events');
    final events = CareApi.extractList(data, ['events', 'items', 'results'])
        .map(PetEvent.fromJson)
        .toList();
    events.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return events;
  }

  Future<void> addEvent({
    required String title,
    required String category,
    required String fullDate,
    required String time,
    required String location,
    required String description,
  }) async {
    final date = parseCareDate(fullDate);
    if (date == null) {
      throw const CareApiException('Enter the date like "Dec 05, 2026".');
    }

    await CareApi.post('/events', {
      'title': title,
      'organizerName': 'PetMate Official',
      'category': category,
      'dayName': weekdayShort(date),
      'dayNum': date.day.toString(),
      'fullDate': formatCareDate(date),
      'time': time,
      'location': location,
      'description': description,
    });

    try {
      await refresh();
    } catch (_) {
      // The event was created; a failed refresh must not report a failure.
    }
  }

  /// Book (`true`) or cancel (`false`) a spot. Updates the UI immediately and
  /// rolls back if the server rejects it. Throws [CareApiException] on failure.
  Future<void> toggleRsvp(String eventId, bool book) {
    return _mutate(
      eventId,
      'rsvp',
      apply: (e) => e.copyWith(
        isBooked: book,
        attendeeCount: _bump(e.attendeeCount, book ? 1 : -1),
      ),
      revert: (e) => e.copyWith(
        isBooked: !book,
        attendeeCount: _bump(e.attendeeCount, book ? -1 : 1),
      ),
      request: () =>
          CareApi.post('/events/$eventId/rsvp', {'isBooked': book}),
    );
  }

  Future<void> toggleBookmark(String eventId, bool bookmark) {
    return _mutate(
      eventId,
      'bookmark',
      apply: (e) => e.copyWith(isBookmarked: bookmark),
      revert: (e) => e.copyWith(isBookmarked: !bookmark),
      request: () =>
          CareApi.post('/events/$eventId/bookmark', {'isBookmarked': bookmark}),
    );
  }

  int _bump(int n, int by) => (n + by) < 0 ? 0 : n + by;

  Future<void> _mutate(
    String eventId,
    String action, {
    required PetEvent Function(PetEvent) apply,
    required PetEvent Function(PetEvent) revert,
    required Future<dynamic> Function() request,
  }) async {
    final key = '$eventId:$action';
    if (!_pending.add(key)) return;

    List<PetEvent> patch(PetEvent Function(PetEvent) fn) => [
          for (final e in state.value ?? const <PetEvent>[])
            e.id == eventId ? fn(e) : e,
        ];

    state = AsyncData(patch(apply));
    try {
      await request();
    } catch (_) {
      state = AsyncData(patch(revert));
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }
}

// ==========================================
// 2. VETERINARIANS
// ==========================================
final careVetsProvider =
    AsyncNotifierProvider<CareVetsNotifier, List<Vet>>(CareVetsNotifier.new);

final veterinariansProvider = careVetsProvider;

class CareVetsNotifier extends AsyncNotifier<List<Vet>> {
  @override
  Future<List<Vet>> build() => _fetchVets();

  Future<void> loadVets() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchVets);
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetchVets());
  }

  Future<List<Vet>> _fetchVets() async {
    final data = await CareApi.get('/veterinarians');
    return CareApi.extractList(data, ['veterinarians', 'vets', 'items'])
        .map(Vet.fromJson)
        .toList();
  }

  Future<void> addVeterinarian({
    required String name,
    required String email,
    required String password,
    required String clinicName,
    required String licenseNumber,
    required String specialty,
    required String address,
    required int fee,
  }) async {
    await CareApi.post('/veterinarians', {
      'name': name,
      'email': email,
      'password': password,
      'clinicName': clinicName,
      'licenseNumber': licenseNumber,
      'specialty': specialty,
      'address': address,
      'fee': fee,
    });

    try {
      await refresh();
    } catch (_) {
      // Created successfully; ignore refresh failure.
    }
  }

  /// Admin edit of an existing doctor (`PATCH /veterinarians/:id`).
  Future<void> updateVeterinarian(
    String vetId, {
    required String name,
    required String clinicName,
    required String specialty,
    required String address,
    required int fee,
    required bool isAcceptingBookings,
  }) async {
    await CareApi.patch('/veterinarians/$vetId', {
      'name': name,
      'clinicName': clinicName,
      'specialty': specialty,
      'address': address,
      'fee': fee,
      'isAcceptingBookings': isAcceptingBookings,
    });
    state = AsyncData([
      for (final v in state.value ?? const <Vet>[])
        v.id == vetId
            ? v.copyWith(
                name: name,
                clinicName: clinicName,
                specialty: specialty,
                address: address,
                fee: fee,
                isAcceptingBookings: isAcceptingBookings,
              )
            : v,
    ]);
    ref.invalidate(myVetProfileProvider);
  }

  Future<void> updateSlots(String vetId, List<String> slots) async {
    final sorted = sortedSlots(slots);
    await CareApi.patch('/veterinarians/$vetId/slots', {
      'availableSlots': sorted,
    });
    state = AsyncData([
      for (final v in state.value ?? const <Vet>[])
        v.id == vetId ? v.copyWith(availableSlots: sorted) : v,
    ]);
    ref.invalidate(myVetProfileProvider);
  }
}

/// The clinic profile of the signed-in veterinarian (null if none is linked).
///
/// Asks the backend for `GET /veterinarians/me`; if that route does not exist
/// yet (404) it falls back to matching the signed-in email against the vet list.
final myVetProfileProvider = FutureProvider<Vet?>((ref) async {
  try {
    final data = await CareApi.get('/veterinarians/me');
    final map = CareApi.extractMap(data, ['veterinarian', 'vet']);
    return map == null ? null : Vet.fromJson(map);
  } on CareApiException catch (e) {
    if (e.statusCode != 404) rethrow;
  }

  final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
  if (email == null) return null;
  final vets = await ref.watch(careVetsProvider.future);
  for (final v in vets) {
    if (v.email?.toLowerCase() == email) return v;
  }
  return null;
});

// ==========================================
// 3. APPOINTMENTS
// ==========================================
final appointmentsProvider =
    AsyncNotifierProvider<AppointmentsNotifier, List<Appointment>>(
        AppointmentsNotifier.new);

class AppointmentsNotifier extends AsyncNotifier<List<Appointment>> {
  @override
  Future<List<Appointment>> build() => _fetchAppointments();

  Future<void> refresh() async {
    state = AsyncData(await _fetchAppointments());
  }

  Future<List<Appointment>> _fetchAppointments() async {
    final data = await CareApi.get('/appointments');
    final list = CareApi.extractList(data, ['appointments', 'items'])
        .map(Appointment.fromJson)
        .toList();

    // Upcoming first (soonest on top), then history (most recent on top).
    list.sort((a, b) {
      if (a.isUpcoming != b.isUpcoming) return a.isUpcoming ? -1 : 1;
      final sa = a.startsAt, sb = b.startsAt;
      if (sa == null || sb == null) return 0;
      return a.isUpcoming ? sa.compareTo(sb) : sb.compareTo(sa);
    });
    return list;
  }

  Future<void> bookAppointment({
    required String petName,
    required String vetId,
    required String date,
    required String timeSlot,
    required String reason,
  }) async {
    await CareApi.post('/appointments', {
      'petName': petName,
      'vetId': vetId,
      'date': date,
      'timeSlot': timeSlot,
      'reason': reason,
    });

    try {
      await refresh();
    } catch (_) {
      // Booked successfully; the list will reload on next open.
    }
  }

  Future<void> updateStatus(
    String id, {
    required String status,
    String? vetNotes,
    String? nextVaccineDue,
  }) async {
    final previous = state.value ?? const <Appointment>[];
    final next = Appointment.normalizeStatus(status);

    state = AsyncData([
      for (final a in previous)
        a.id == id
            ? a.copyWith(
                status: next,
                vetNotes: vetNotes,
                nextVaccineDue: nextVaccineDue,
              )
            : a,
    ]);

    try {
      await CareApi.patch('/appointments/$id/status', {
        'status': status.toUpperCase(),
        if (vetNotes != null) 'vetNotes': vetNotes,
        if (nextVaccineDue != null) 'nextVaccineDue': nextVaccineDue,
      });
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

/// Earliest vaccine due date (today or later) recorded by a vet, if any.
final nextVaccineDueProvider = Provider<DateTime?>((ref) {
  final appts = ref.watch(appointmentsProvider).maybeWhen(
        data: (list) => list,
        orElse: () => const <Appointment>[],
      );
  final today = todayDate();
  DateTime? best;
  for (final a in appts) {
    final d = parseCareDate(a.nextVaccineDue);
    if (d == null || d.isBefore(today)) continue;
    if (best == null || d.isBefore(best)) best = d;
  }
  return best;
});
