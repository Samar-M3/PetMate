class Vet {
  final String id;
  final String name;
  final String clinicName;
  final String specialty;
  final String address;
  final double rating;
  final int fee;
  final bool isVerified;
  final bool isAcceptingBookings;
  final List<String> availableSlots;

  Vet({
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
  });

  factory Vet.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['availableSlots'] ?? json['available_slots'];
    final slotsList = rawSlots is List
        ? rawSlots.map((s) => s.toString()).toList()
        : <String>['10:00 AM', '01:00 PM', '03:30 PM'];

    return Vet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      clinicName: json['clinicName'] as String? ?? json['clinic_name'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      address: json['address'] as String? ?? '',
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 5.0,
      fee: (json['fee'] is num) ? (json['fee'] as num).toInt() : 500,
      isVerified: json['isVerified'] as bool? ?? json['is_verified'] as bool? ?? true,
      isAcceptingBookings: json['isAcceptingBookings'] as bool? ?? json['is_accepting_bookings'] as bool? ?? true,
      availableSlots: slotsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clinicName': clinicName,
      'specialty': specialty,
      'address': address,
      'rating': rating,
      'fee': fee,
      'isVerified': isVerified,
      'isAcceptingBookings': isAcceptingBookings,
      'availableSlots': availableSlots,
    };
  }
}
