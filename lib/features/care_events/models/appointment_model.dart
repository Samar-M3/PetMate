import '../utils/care_format.dart';

class Appointment {
  static const String upcoming = 'Upcoming';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  final String id;
  final String petName;
  final String vetId;
  final String vetName;
  final String clinicName;
  final String date; // 'Nov 24, 2026'
  final String timeSlot; // '09:30 AM'
  final String reason;
  final String status; // upcoming | completed | cancelled
  final String? vetNotes;
  final String? nextVaccineDue;

  const Appointment({
    required this.id,
    required this.petName,
    required this.vetId,
    required this.vetName,
    required this.clinicName,
    required this.date,
    required this.timeSlot,
    required this.reason,
    this.status = upcoming,
    this.vetNotes,
    this.nextVaccineDue,
  });

  factory Appointment.fromJson(Map<String, dynamic> j) {
    final vetNode = j['vet'];
    return Appointment(
      id: j['id'].toString(),
      petName: (j['petName'] ?? j['pet']?['name'] ?? 'My Pet').toString(),
      vetId: (j['vetId'] ?? vetNode?['id'] ?? '').toString(),
      vetName:
          (vetNode?['name'] ??
                  j['vetName'] ??
                  vetNode?['user']?['profile']?['fullName'] ??
                  'Veterinarian')
              .toString(),
      clinicName: (vetNode?['clinicName'] ?? j['clinicName'] ?? 'Clinic')
          .toString(),
      date: displayCareDate((j['date'] ?? '').toString()),
      timeSlot: (j['timeSlot'] ?? '').toString(),
      reason: (j['reason'] ?? 'General Checkup').toString(),
      status: normalizeStatus(j['status']),
      vetNotes: _nullIfEmpty(j['vetNotes']),
      nextVaccineDue: _nullIfEmpty(j['nextVaccineDue']),
    );
  }

  Appointment copyWith({
    String? status,
    String? vetNotes,
    String? nextVaccineDue,
  }) {
    return Appointment(
      id: id,
      petName: petName,
      vetId: vetId,
      vetName: vetName,
      clinicName: clinicName,
      date: date,
      timeSlot: timeSlot,
      reason: reason,
      status: status ?? this.status,
      vetNotes: vetNotes ?? this.vetNotes,
      nextVaccineDue: nextVaccineDue ?? this.nextVaccineDue,
    );
  }

  bool get isUpcoming => status == upcoming;

  /// Appointment start, for sorting. Null if the date can't be parsed.
  DateTime? get startsAt {
    final d = parseCareDate(date);
    if (d == null) return null;
    final minutes = slotMinutes(timeSlot) ?? 0;
    return d.add(Duration(minutes: minutes));
  }

  static String normalizeStatus(dynamic raw) {
    final s = (raw ?? 'UPCOMING').toString().toUpperCase();
    if (s == 'COMPLETED') return completed;
    if (s == 'CANCELLED' || s == 'CANCELED') return cancelled;
    return upcoming;
  }

  static String? _nullIfEmpty(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
