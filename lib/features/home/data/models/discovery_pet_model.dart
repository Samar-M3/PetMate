import '../../domain/entities/discovery_pet.dart';

class DiscoveryPetModel extends DiscoveryPet {
  const DiscoveryPetModel({
    required super.id,
    required super.petName,
    required super.petAge,
    required super.petBreed,
    required super.petGender,
    required super.petBio,
    required super.petImageUrl,
    super.photos = const [],
    required super.personality,
    super.species,
    super.color,
    super.purpose,
    super.isNeutered,
    super.weightKg,
    super.sizeCategory,
    super.vaccinationStatus,
    super.lastVaccinatedDate,
    required super.ownerName,
    super.ownerUsername,
    super.ownerId,
    super.ownerAge,
    required super.ownerLocation,
    super.ownerAvatarUrl,
  });

  factory DiscoveryPetModel.fromJson(Map<String, dynamic> json) {
    final parsedPhotos = (json['photos'] as List<dynamic>?)
            ?.map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final candidateImages = <String?>[
      json['petImageUrl'] as String?,
      json['imageUrl'] as String?,
      json['profilePictureUrl'] as String?,
      ...parsedPhotos,
    ];
    final rawImageUrl = candidateImages
            .map((e) => e?.trim() ?? '')
            .firstWhere((e) => e.isNotEmpty, orElse: () => '');

    final rawWeight = json['weightKg'];
    final double? weightKg = rawWeight is num ? rawWeight.toDouble() : null;

    return DiscoveryPetModel(
      id: json['id'] as String? ?? '',
      petName: json['petName'] as String? ?? json['name'] as String? ?? '',
      petAge: json['petAge'] as String? ?? '1.0 years',
      petBreed: json['petBreed'] as String? ?? json['breed'] as String? ?? '',
      petGender:
          json['petGender'] as String? ?? json['gender'] as String? ?? 'Male',
      petBio:
          json['petBio'] as String? ??
          json['bio'] as String? ??
          json['description'] as String? ??
          '',
      petImageUrl: rawImageUrl,
      photos: parsedPhotos.isNotEmpty
          ? parsedPhotos
          : (rawImageUrl.isNotEmpty ? [rawImageUrl] : []),
      personality:
          (json['personality'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      species: json['species'] as String? ?? json['animalType'] as String?,
      color: json['color'] as String? ?? json['colorCoat'] as String?,
      purpose: json['purpose'] as String?,
      isNeutered: json['isNeutered'] as bool?,
      weightKg: weightKg,
      sizeCategory: json['sizeCategory'] as String?,
      vaccinationStatus: json['vaccinationStatus'] as String?,
      lastVaccinatedDate: json['lastVaccinatedDate'] as String?,
      ownerName:
          json['ownerName'] as String? ??
          json['ownerUsername'] as String? ??
          'Pet Parent',
      ownerUsername:
          json['ownerUsername'] as String? ?? json['ownerName'] as String?,
      ownerId: json['ownerId'] as String?,
      ownerAge: json['ownerAge'] as String?,
      ownerLocation:
          json['ownerLocation'] as String? ??
          json['area'] as String? ??
          'Kathmandu, Nepal',
      ownerAvatarUrl: json['ownerAvatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petName': petName,
      'petAge': petAge,
      'petBreed': petBreed,
      'petGender': petGender,
      'petBio': petBio,
      'petImageUrl': petImageUrl,
      'photos': photos,
      'personality': personality,
      'species': species,
      'color': color,
      'purpose': purpose,
      'isNeutered': isNeutered,
      'weightKg': weightKg,
      'sizeCategory': sizeCategory,
      'vaccinationStatus': vaccinationStatus,
      'lastVaccinatedDate': lastVaccinatedDate,
      'ownerName': ownerName,
      'ownerUsername': ownerUsername,
      'ownerId': ownerId,
      'ownerAge': ownerAge,
      'ownerLocation': ownerLocation,
      'ownerAvatarUrl': ownerAvatarUrl,
    };
  }

  static const List<DiscoveryPetModel> curatedMockPets = [
    DiscoveryPetModel(
      id: 'pet_01',
      petName: 'Milo',
      petAge: '2 years old',
      petBreed: 'Golden Retriever',
      petGender: 'Male',
      petBio: 'Always ready for a park run or fetching tennis balls. Loves meeting gentle dogs!',
      petImageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=1000&q=80',
      personality: ['Friendly', 'Active', 'Playful', 'Social'],
      ownerName: 'Aarav Sharma',
      ownerAge: '26',
      ownerLocation: 'Jhamsikhel, Lalitpur',
      ownerAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
    ),
    DiscoveryPetModel(
      id: 'pet_02',
      petName: 'Luna',
      petAge: '1.5 years old',
      petBreed: 'Siberian Husky',
      petGender: 'Female',
      petBio: 'Blue-eyed vocal queen. Loves hiking, cold morning walks, and belly scratches.',
      petImageUrl: 'https://images.unsplash.com/photo-1605568427561-40dd23c2acea?auto=format&fit=crop&w=1000&q=80',
      personality: ['Energetic', 'Playful', 'Vocal', 'Calm'],
      ownerName: 'Pooja Thapa',
      ownerAge: '24',
      ownerLocation: 'Baluwatar, Kathmandu',
      ownerAvatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
    ),
    DiscoveryPetModel(
      id: 'pet_03',
      petName: 'Bella',
      petAge: '3 years old',
      petBreed: 'British Shorthair',
      petGender: 'Female',
      petBio: 'Sophisticated indoor cat looking for calm playdates and windowsill sunbathing.',
      petImageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=1000&q=80',
      personality: ['Calm', 'Affectionate', 'Independent'],
      ownerName: 'Rohan KC',
      ownerAge: '28',
      ownerLocation: 'Sanepa, Lalitpur',
      ownerAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
    ),
    DiscoveryPetModel(
      id: 'pet_04',
      petName: 'Charlie',
      petAge: '1 year old',
      petBreed: 'French Bulldog',
      petGender: 'Male',
      petBio: 'Small size, huge personality! Champion napper and professional treat tester.',
      petImageUrl: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=1000&q=80',
      personality: ['Playful', 'Affectionate', 'Social'],
      ownerName: 'Sneha Shrestha',
      ownerAge: '25',
      ownerLocation: 'Lazimpat, Kathmandu',
      ownerAvatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
    ),
    DiscoveryPetModel(
      id: 'pet_05',
      petName: 'Oreo',
      petAge: '8 months old',
      petBreed: 'Holland Lop Rabbit',
      petGender: 'Male',
      petBio: 'Curious bunny who loves fresh cilantro and hopping around in safe grass areas.',
      petImageUrl: 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=1000&q=80',
      personality: ['Gentle', 'Quiet', 'Curious'],
      ownerName: 'Bikash Rana',
      ownerAge: '29',
      ownerLocation: 'Baneshwor, Kathmandu',
      ownerAvatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
    ),
  ];
}
