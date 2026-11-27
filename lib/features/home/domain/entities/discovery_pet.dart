class DiscoveryPet {
  final String id;
  final String petName;
  final String petAge;
  final String petBreed;
  final String petGender;
  final String petBio;
  final String petImageUrl;
  final List<String> photos;
  final List<String> personality;
  final String? species;
  final String? color;
  final String? purpose;
  final bool? isNeutered;
  final double? weightKg;
  final String? sizeCategory;
  final String? vaccinationStatus;
  final String? lastVaccinatedDate;
  final String ownerName;
  final String? ownerUsername;
  final String? ownerId;
  final String? ownerAge;
  final String ownerLocation;
  final String? ownerAvatarUrl;
  final String? species;

  const DiscoveryPet({
    required this.id,
    required this.petName,
    required this.petAge,
    required this.petBreed,
    required this.petGender,
    required this.petBio,
    required this.petImageUrl,
    this.photos = const [],
    required this.personality,
    this.species,
    this.color,
    this.purpose,
    this.isNeutered,
    this.weightKg,
    this.sizeCategory,
    this.vaccinationStatus,
    this.lastVaccinatedDate,
    required this.ownerName,
    this.ownerUsername,
    this.ownerId,
    this.ownerAge,
    required this.ownerLocation,
    this.ownerAvatarUrl,
    this.species,
  });
}
