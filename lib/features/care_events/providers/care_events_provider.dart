import 'dart:convert';
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
// 1. EVENTS PROVIDER
// ==========================================
final careEventsProvider =
AsyncNotifierProvider<CareEventsNotifier, List<PetEvent>>(
    CareEventsNotifier.new);

class CareEventsNotifier extends AsyncNotifier<List<PetEvent>> {
  @override
  Future<List<PetEvent>> build() async {
    return _fetchEvents();
  }

  Future<void> loadEvents() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchEvents);
  }

  Future<List<PetEvent>> _fetchEvents() async {
    final headers = await _getHeaders();
    final res = await http.get(Uri.parse('$_apiBase/events'), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load events (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    final list = _extractList(decoded, ['events', 'items', 'results']);
    return list.map((j) => _mapEvent(j as Map<String, dynamic>)).toList();
  }

  PetEvent _mapEvent(Map<String, dynamic> j) {
    final fullDate =
    (j['fullDate'] ?? j['eventDate'] ?? j['date'] ?? 'Dec 05, 2026')
        .toString();
    final parts = fullDate.split(' ');
    final parsedDay = parts.length > 1 ? parts[1].replaceAll(',', '') : '05';

    return PetEvent(
      id: j['id'].toString(),
      title: j['title'] ?? '',
      category: j['category'] ?? 'MEETUP',
      dayName: j['dayName'] ?? 'SUN',
      dayNum: j['dayNum']?.toString() ?? parsedDay,
      fullDate: fullDate,
      time: j['time'] ?? '10:00 AM - 01:00 PM',
      location: j['location'] ?? '',
      description: j['description'] ?? '',
      attendeeCount: (j['attendeeCount'] as num?)?.toInt() ?? 0,
      isBookmarked: j['isBookmarked'] ?? false,
      isBooked: j['isBooked'] ?? false,
    );
  }

  Future<void> addEvent({
    required String title,
    required String category,
    required String fullDate,
    required String time,
    required String location,
    required String description,
  }) async {
    final headers = await _getHeaders();
    final parts = fullDate.split(' ');
    final dayNum = parts.length > 1 ? parts[1].replaceAll(',', '') : '05';

    final res = await http.post(
      Uri.parse('$_apiBase/events'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'organizerName': 'PetMate Official',
        'category': category,
        'dayName': 'SUN',
        'dayNum': dayNum,
        'fullDate': fullDate,
        'time': time,
        'location': location,
        'description': description,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      await loadEvents();
    } else {
      throw Exception('Failed to create event: ${res.body}');
    }
  }

  Future<void> toggleRsvp(String eventId, bool book) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$_apiBase/events/$eventId/rsvp'),
      headers: headers,
      body: jsonEncode({'isBooked': book}),
    );
    await loadEvents();
  }

  Future<void> toggleBookmark(String eventId, bool bookmark) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$_apiBase/events/$eventId/bookmark'),
      headers: headers,
      body: jsonEncode({'isBookmarked': bookmark}),
    );
    await loadEvents();
  }
}

// ==========================================
// 2. VETERINARIANS PROVIDER
// ==========================================
final careVetsProvider =
AsyncNotifierProvider<CareVetsNotifier, List<Vet>>(CareVetsNotifier.new);

final veterinariansProvider = careVetsProvider;

class CareVetsNotifier extends AsyncNotifier<List<Vet>> {
  @override
  Future<List<Vet>> build() async {
    return _fetchVets();
  }

  Future<void> loadVets() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchVets);
  }

  Future<List<Vet>> _fetchVets() async {
    final headers = await _getHeaders();
    final res =
    await http.get(Uri.parse('$_apiBase/veterinarians'), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load veterinarians (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    final list = _extractList(decoded, ['veterinarians', 'vets', 'items']);
    return list.map((item) {
      final j = item as Map<String, dynamic>;
      return Vet(
        id: j['id'].toString(),
        name: j['name'] ?? j['fullName'] ?? j['user']?['profile']?['fullName'] ?? 'Veterinarian',
        clinicName: j['clinicName'] ?? 'PetMate Partner Clinic',
        specialty: j['specialty'] ?? 'General Veterinary Care',
        address: j['address'] ?? 'Lalitpur',
        rating: (j['rating'] as num?)?.toDouble() ?? 5.0,
        fee: (j['fee'] as num?)?.toInt() ?? 500,
        isVerified: j['isVerified'] ?? true,
        isAcceptingBookings: j['isAcceptingBookings'] ?? true,
        availableSlots: List<String>.from(
          j['availableSlots'] ??
              ['09:30 AM', '11:00 AM', '02:30 PM', '04:45 PM'],
        ),
      );
    }).toList();
  }

  // Posts to /api/veterinarians (matching your backend's existing route prefix)
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
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$_apiBase/veterinarians'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'clinicName': clinicName,
        'licenseNumber': licenseNumber,
        'specialty': specialty,
        'address': address,
        'fee': fee,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      await loadVets();
    } else {
      throw Exception('Failed to add veterinarian: ${res.body}');
    }
  }

  Future<void> updateSlots(String vetId, List<String> slots) async {
    final headers = await _getHeaders();
    await http.patch(
      Uri.parse('$_apiBase/veterinarians/$vetId/slots'),
      headers: headers,
      body: jsonEncode({'availableSlots': slots}),
    );
    await loadVets();
  }
}

// ==========================================
// 3. APPOINTMENTS PROVIDER
// ==========================================
final appointmentsProvider =
AsyncNotifierProvider<AppointmentsNotifier, List<Appointment>>(
    AppointmentsNotifier.new);

class AppointmentsNotifier extends AsyncNotifier<List<Appointment>> {
@override
Future<List<Appointment>> build() async {
return _fetchAppointments();
}

Future<List<Appointment>> _fetchAppointments() async {
final headers = await _getHeaders();
final res =
await http.get(Uri.parse('$_apiBase/appointments'), headers: headers);
if (res.statusCode != 200) {
return [];
}
final decoded = jsonDecode(res.body);
final list = _extractList(decoded, ['appointments', 'items']);
return list.map((item) {
final j = item as Map<String, dynamic>;
return Appointment(
id: j['id'].toString(),
petName: j['petName'] ?? j['pet']?['name'] ?? 'My Pet',
vetId: j['vetId'].toString(),
vetName: j['vet']?['name'] ?? j['vetName'] ?? 'Veterinarian',
clinicName: j['vet']?['clinicName'] ?? j['clinicName'] ?? 'Clinic',
date: j['date'] ?? '',
timeSlot: j['timeSlot'] ?? '',
reason: j['reason'] ?? 'General Checkup',
status: _formatStatus(j['status']),
vetNotes: j['vetNotes'],
nextVaccineDue: j['nextVaccineDue'],
);
}).toList();
}

String _formatStatus(dynamic raw) {
final s = (raw ?? 'UPCOMING').toString().toUpperCase();
if (s == 'COMPLETED') return 'Completed';
if (s == 'CANCELLED') return 'Cancelled';
return 'Upcoming';
}

Future<void> bookAppointment({
required String petName,
required String vetId,
required String date,
required String timeSlot,
required String reason,
}) async {
final headers = await _getHeaders();
final res = await http.post(
Uri.parse('$_apiBase/appointments'),
headers: headers,
body: jsonEncode({
'petName': petName,
'vetId': vetId,
'date': date,
'timeSlot': timeSlot,
'reason': reason,
}),
);

if (res.statusCode == 200 || res.statusCode == 201) {
ref.invalidateSelf();
} else {
throw Exception('Booking failed: ${res.body}');
}
}

Future<void> updateStatus(
String id, {
required String status,
String? vetNotes,
      String? nextVaccineDue,
    }) async {
  final headers = await _getHeaders();
  await http.patch(
    Uri.parse('$_apiBase/appointments/$id/status'),
    headers: headers,
    body: jsonEncode({
      'status': status.toUpperCase(),
      'vetNotes': vetNotes,
      'nextVaccineDue': nextVaccineDue,
    }),
  );
  ref.invalidateSelf();
}
}