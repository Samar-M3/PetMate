import '../utils/care_format.dart';

class Vet {
  final String id;
  final String name;
  final String clinicName;
  final String specialty;
  final String address;
  final double rating; // 0 means "no ratings yet"
  final int fee;
  final bool isVerified;
  final bool isAcceptingBookings;
  final List<String> availableSlots;
  final String? email;

  const Vet({
    required this.id,
    required this.name,
    required this.clinicName,
    required this.specialty,
    required this.address,
    required this.rating,
    required this.fee,
    this.isVerified = true,
    this.isAcceptingBookings = true,
    required this.availableSlots,
    this.email,
  });

  factory Vet.fromJson(Map<String, dynamic> j) {
    final rawSlots = j['availableSlots'] ?? j['available_slots'];
    final slots = rawSlots is List
        ? sortedSlots(rawSlots.map((s) => s.toString()))
        : <String>[];

    return Vet(
      id: j['id'].toString(),
      name: (j['name'] ??
              j['fullName'] ??
              j['user']?['profile']?['fullName'] ??
              'Veterinarian')
          .toString(),
      clinicName: (j['clinicName'] ?? 'Partner Clinic').toString(),
      specialty: (j['specialty'] ?? 'General Veterinary Care').toString(),
      address: (j['address'] ?? '').toString(),
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      fee: (j['fee'] as num?)?.toInt() ?? 0,
      isVerified: j['isVerified'] == true,
      isAcceptingBookings: j['isAcceptingBookings'] == true,
      availableSlots: slots,
      email: (j['email'] ?? j['user']?['email'])?.toString(),
    );
  }

  Vet copyWith({
    String? name,
    String? clinicName,
    String? specialty,
    String? address,
    int? fee,
    bool? isAcceptingBookings,
    List<String>? availableSlots,
  }) {
    return Vet(
      id: id,
      name: name ?? this.name,
      clinicName: clinicName ?? this.clinicName,
      specialty: specialty ?? this.specialty,
      address: address ?? this.address,
      rating: rating,
      fee: fee ?? this.fee,
      isVerified: isVerified,
      isAcceptingBookings: isAcceptingBookings ?? this.isAcceptingBookings,
      availableSlots: availableSlots ?? this.availableSlots,
      email: email,
    );
  }
}
