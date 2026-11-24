class PublicPetCardSummary {
  final String id;
  final String name;
  final String species;
  final String breed;
  final int ageMonths;
  final String ageString;
  final String photoUrl;

  const PublicPetCardSummary({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.ageMonths,
    required this.ageString,
    required this.photoUrl,
  });

  factory PublicPetCardSummary.fromJson(Map<String, dynamic> json) {
    return PublicPetCardSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pet',
      species: json['species'] as String? ?? 'Pet',
      breed: json['breed'] as String? ?? 'Mixed',
      ageMonths: json['ageMonths'] as int? ?? 0,
      ageString: json['ageString'] as String? ?? '1 yr old',
      photoUrl: json['photoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    'breed': breed,
    'ageMonths': ageMonths,
    'ageString': ageString,
    'photoUrl': photoUrl,
  };
}

class PublicUserProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String memberSince;
  final String? area;
  final String? bio;
  final List<PublicPetCardSummary> pets;

  const PublicUserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.memberSince,
    this.area,
    this.bio,
    required this.pets,
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    final petsList =
        (json['pets'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((p) => PublicPetCardSummary.fromJson(p))
            .toList() ??
        [];

    return PublicUserProfile(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Pet Parent',
      avatarUrl: json['avatarUrl'] as String?,
      memberSince: json['memberSince'] as String? ?? '',
      area: json['area'] as String?,
      bio: json['bio'] as String?,
      pets: petsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'memberSince': memberSince,
    'area': area,
    'bio': bio,
    'pets': pets.map((p) => p.toJson()).toList(),
  };
}
