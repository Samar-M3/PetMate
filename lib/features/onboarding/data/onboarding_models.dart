class UploadedAsset {
  final String url;
  final String publicId;

  const UploadedAsset({required this.url, required this.publicId});
}

class PetPhotoItem {
  final String url;
  final String publicId;
  final int position;
  final bool isPrimary;

  const PetPhotoItem({
    required this.url,
    required this.publicId,
    required this.position,
    this.isPrimary = false,
  });

  PetPhotoItem copyWith({
    String? url,
    String? publicId,
    int? position,
    bool? isPrimary,
  }) {
    return PetPhotoItem(
      url: url ?? this.url,
      publicId: publicId ?? this.publicId,
      position: position ?? this.position,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  factory PetPhotoItem.fromJson(Map<String, dynamic> json, int index) {
    return PetPhotoItem(
      url: (json['imageUrl'] ?? json['url'] ?? '').toString(),
      publicId: (json['imagePublicId'] ?? json['publicId'] ?? '').toString(),
      position: (json['position'] as num?)?.toInt() ?? index,
      isPrimary: json['isMain'] as bool? ?? json['isPrimary'] as bool? ?? index == 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'publicId': publicId,
        'position': position,
        'isPrimary': isPrimary,
      };
}

class OnboardingPetData {
  final String id;
  final String name;
  final String species;
  final String? speciesOther;
  final String breed;
  final String gender;
  final DateTime? dateOfBirth;
  final List<PetPhotoItem> photos;

  // Page 3
  final String purpose;
  final bool isNeutered;
  final bool? hasLitters;
  final int? litterCount;
  final List<String> temperament;
  final double? weightKg;
  final String? sizeCategory;
  final String? colorCoat;
  final bool hasPedigree;
  final String? pedigreeCertUrl;
  final String? bio;
  final String? city;
  final String? district;

  // Page 4
  final String vaccinationStatus;
  String get vaccinationLevel => vaccinationStatus;
  final DateTime? rabiesVaccineDate;
  final String? healthNotes;
  final String? lastCheckup;
  final List<String> vetRecordUrls;
  final String profileStatus;

  const OnboardingPetData({
    required this.id,
    required this.name,
    required this.species,
    this.speciesOther,
    required this.breed,
    required this.gender,
    this.dateOfBirth,
    this.photos = const [],
    this.purpose = 'COMPANION',
    this.isNeutered = false,
    this.hasLitters,
    this.litterCount,
    this.temperament = const [],
    this.weightKg,
    this.sizeCategory,
    this.colorCoat,
    this.hasPedigree = false,
    this.pedigreeCertUrl,
    this.bio,
    this.city,
    this.district,
    this.vaccinationStatus = 'NONE',
    this.rabiesVaccineDate,
    this.healthNotes,
    this.lastCheckup,
    this.vetRecordUrls = const [],
    this.profileStatus = 'DRAFT',
  });

  int get ageYears {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  int get ageMonths {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int months = (now.month - dateOfBirth!.month);
    if (now.day < dateOfBirth!.day) months--;
    if (months < 0) months += 12;
    return months.clamp(0, 11);
  }

  factory OnboardingPetData.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final photos = <PetPhotoItem>[];
    for (var i = 0; i < rawImages.length; i++) {
      photos.add(PetPhotoItem.fromJson(Map<String, dynamic>.from(rawImages[i]), i));
    }
    if (photos.isEmpty && json['imageUrl'] != null) {
      photos.add(PetPhotoItem(
        url: json['imageUrl'].toString(),
        publicId: (json['imagePublicId'] ?? '').toString(),
        position: 0,
        isPrimary: true,
      ));
    }

    final rawSpecies = (json['species'] ?? json['animalType'] ?? 'DOG')
        .toString()
        .toUpperCase();
    final species = ['DOG', 'CAT', 'BIRD', 'RABBIT', 'HAMSTER', 'OTHER']
            .contains(rawSpecies)
        ? rawSpecies
        : 'OTHER';

    final rawGender = (json['gender'] ?? 'MALE').toString().toUpperCase();
    final gender = rawGender == 'FEMALE' ? 'FEMALE' : 'MALE';

    return OnboardingPetData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      species: species,
      speciesOther: json['speciesOther'] as String?,
      breed: json['breed']?.toString() ?? '',
      gender: gender,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      photos: photos,
      purpose: (json['purpose'] ?? 'COMPANION').toString().toUpperCase(),
      isNeutered: json['isNeutered'] as bool? ?? false,
      hasLitters: json['hasLitters'] as bool?,
      litterCount: (json['litterCount'] as num?)?.toInt(),
      temperament: (json['temperament'] as List? ??
              json['personality'] as List? ??
              const [])
          .map((e) => e.toString())
          .toList(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      sizeCategory: json['sizeCategory'] as String?,
      colorCoat: (json['colorCoat'] ?? json['color']) as String?,
      hasPedigree: json['hasPedigree'] as bool? ?? false,
      pedigreeCertUrl: json['pedigreeCertUrl'] as String?,
      bio: (json['bio'] ?? json['description']) as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      vaccinationStatus:
          (json['vaccinationLevel'] ?? json['vaccinationStatus'] ?? 'NONE')
              .toString()
              .toUpperCase(),
      rabiesVaccineDate: json['rabiesVaccineDate'] != null
          ? DateTime.tryParse(json['rabiesVaccineDate'].toString())
          : null,
      healthNotes: (json['healthNotes'] ?? json['allergies']) as String?,
      lastCheckup: json['lastCheckup'] as String?,
      vetRecordUrls: (json['vetRecordUrls'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      profileStatus:
          (json['profileStatus'] ?? 'DRAFT').toString().toUpperCase(),
    );
  }
}

class OwnerProfileData {
  final String id;
  final String userId;
  final String email;
  final String role;
  final String displayName;
  final String? avatarUrl;
  final String city;
  final String district;
  final int onboardingStep;
  final bool onboardingCompleted;
  final bool registrationCompleted;
  final OnboardingPetData? draftPet;

  const OwnerProfileData({
    required this.id,
    required this.userId,
    required this.email,
    this.role = 'PET_OWNER',
    required this.displayName,
    this.avatarUrl,
    required this.city,
    required this.district,
    required this.onboardingStep,
    required this.onboardingCompleted,
    this.registrationCompleted = false,
    this.draftPet,
  });

  factory OwnerProfileData.fromJson(Map<String, dynamic> json) {
    return OwnerProfileData(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'PET_OWNER',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      onboardingStep: ((json['onboardingStep'] as num?)?.toInt() ?? 1).clamp(1, 4),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      registrationCompleted: json['registrationCompleted'] as bool? ??
          json['onboardingCompleted'] as bool? ??
          false,
      draftPet: json['draftPet'] is Map
          ? OnboardingPetData.fromJson(
              Map<String, dynamic>.from(json['draftPet'] as Map),
            )
          : null,
    );
  }
}
