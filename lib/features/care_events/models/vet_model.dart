class Vet {
  final String id;
  final String name;
  final String clinicName;
  final String specialty;
  final String address;
  final double rating;
  final int fee;
  final List<String> availableSlots;
  final bool isOnline;
  final bool isVerified;

  const Vet({
    required this.id,
    required this.name,
    required this.clinicName,
    required this.specialty,
    required this.address,
    required this.rating,
    required this.fee,
    required this.availableSlots,
    this.isOnline = true,
    this.isVerified = true,
  });
}
