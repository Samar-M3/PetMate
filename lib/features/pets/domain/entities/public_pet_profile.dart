class PublicPetOwnerSummary {
  final String id;
  final String displayName;
  final String? avatarUrl;

  const PublicPetOwnerSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  factory PublicPetOwnerSummary.fromJson(Map<String, dynamic> json) {
    return PublicPetOwnerSummary(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Pet Parent',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}

class PublicPetProfile {
  final String id;
  final String name;
  final String species;
  final String breed;
  final String sex;
  final int ageMonths;
  final String ageString;
  final String? weight;
  final String area;
  final String about;
  final List<String> photos;
  final List<String> healthBadges;
  final List<String> personality;
  final PublicPetOwnerSummary owner;
  final String relationship; // NONE | REQUEST_SENT | REQUEST_RECEIVED | MATCHED
  final bool canSwipe;

  const PublicPetProfile({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    required this.ageMonths,
    required this.ageString,
    this.weight,
    required this.area,
    required this.about,
    required this.photos,
    required this.healthBadges,
    required this.personality,
    required this.owner,
    required this.relationship,
    required this.canSwipe,
  });

  factory PublicPetProfile.fromJson(Map<String, dynamic> json) {
    final ownerMap = json['owner'] as Map<String, dynamic>? ?? {};
    return PublicPetProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pet',
      species: json['species'] as String? ?? 'Pet',
      breed: json['breed'] as String? ?? 'Mixed',
      sex: json['sex'] as String? ?? 'Unknown',
      ageMonths: json['ageMonths'] as int? ?? 0,
      ageString: json['ageString'] as String? ?? '1 yr old',
      weight: json['weight'] as String?,
      area: json['area'] as String? ?? 'Kathmandu, Nepal',
      about: json['about'] as String? ?? '',
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      healthBadges:
          (json['healthBadges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      personality:
          (json['personality'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      owner: PublicPetOwnerSummary.fromJson(ownerMap),
      relationship: json['relationship'] as String? ?? 'NONE',
      canSwipe: json['canSwipe'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    'breed': breed,
    'sex': sex,
    'ageMonths': ageMonths,
    'ageString': ageString,
    'weight': weight,
    'area': area,
    'about': about,
    'photos': photos,
    'healthBadges': healthBadges,
    'personality': personality,
    'owner': owner.toJson(),
    'relationship': relationship,
    'canSwipe': canSwipe,
  };
}
