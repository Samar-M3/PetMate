class DiscoveryPet {
  final String id;
  final String petName;
  final String petAge;
  final String petBreed;
  final String petGender;
  final String petBio;
  final String petImageUrl;
  final List<String> personality;
  final String ownerName;
  final String? ownerAge;
  final String ownerLocation;
  final String? ownerAvatarUrl;

  const DiscoveryPet({
    required this.id,
    required this.petName,
    required this.petAge,
    required this.petBreed,
    required this.petGender,
    required this.petBio,
    required this.petImageUrl,
    required this.personality,
    required this.ownerName,
    this.ownerAge,
    required this.ownerLocation,
    this.ownerAvatarUrl,
  });
}
