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
}
