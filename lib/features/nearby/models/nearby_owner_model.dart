class ApproxLocation {
  final double latitude;
  final double longitude;

  const ApproxLocation({
    required this.latitude,
    required this.longitude,
  });

  factory ApproxLocation.fromJson(Map<String, dynamic> json) {
    return ApproxLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 27.7172,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 85.3240,
    );
  }
}

class NearbyPetModel {
  final String id;
  final String name;
  final String animalType;
  final String breed;
  final double age;
  final String ageString;
  final String gender;
  final String? image;

  const NearbyPetModel({
    required this.id,
    required this.name,
    required this.animalType,
    required this.breed,
    required this.age,
    required this.ageString,
    required this.gender,
    this.image,
  });

  factory NearbyPetModel.fromJson(Map<String, dynamic> json) {
    return NearbyPetModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pet',
      animalType: json['animalType'] as String? ?? 'Pet',
      breed: json['breed'] as String? ?? 'Mixed',
      age: (json['age'] as num?)?.toDouble() ?? 0.0,
      ageString: json['ageString'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Unknown',
      image: json['image'] as String?,
    );
  }
}

class NearbyOwnerModel {
  final String ownerId;
  final String displayName;
  final String? profileImage;
  final String area;
  final double distanceKm;
  final ApproxLocation approxLocation;
  final List<NearbyPetModel> pets;

  const NearbyOwnerModel({
    required this.ownerId,
    required this.displayName,
    this.profileImage,
    required this.area,
    required this.distanceKm,
    required this.approxLocation,
    required this.pets,
  });

  factory NearbyOwnerModel.fromJson(Map<String, dynamic> json) {
    final approxMap = json['approxLocation'] as Map<String, dynamic>? ?? {};
    final petsList = json['pets'] as List<dynamic>? ?? [];

    return NearbyOwnerModel(
      ownerId: json['ownerId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Pet Parent',
      profileImage: json['profileImage'] as String?,
      area: json['area'] as String? ?? 'Nearby',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      approxLocation: ApproxLocation.fromJson(approxMap),
      pets: petsList
          .whereType<Map<String, dynamic>>()
          .map(NearbyPetModel.fromJson)
          .toList(),
    );
  }
}

class NearbyClusterModel {
  final String clusterId;
  final double latitude;
  final double longitude;
  final int ownerCount;
  final String areaLabel;

  const NearbyClusterModel({
    required this.clusterId,
    required this.latitude,
    required this.longitude,
    required this.ownerCount,
    required this.areaLabel,
  });

  factory NearbyClusterModel.fromJson(Map<String, dynamic> json) {
    return NearbyClusterModel(
      clusterId: json['clusterId'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 27.7172,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 85.3240,
      ownerCount: (json['ownerCount'] as num?)?.toInt() ?? 1,
      areaLabel: json['areaLabel'] as String? ?? 'Nearby area',
    );
  }
}

class NearbyCurrentUserLocation {
  final bool locationEnabled;
  final DateTime? locationUpdatedAt;
  final String? area;
  final ApproxLocation? approxLocation;

  const NearbyCurrentUserLocation({
    required this.locationEnabled,
    this.locationUpdatedAt,
    this.area,
    this.approxLocation,
  });

  factory NearbyCurrentUserLocation.fromJson(Map<String, dynamic> json) {
    final approxRaw = json['approxLocation'];
    final updatedRaw = json['locationUpdatedAt'] as String?;
    return NearbyCurrentUserLocation(
      locationEnabled: json['locationEnabled'] as bool? ?? false,
      locationUpdatedAt:
          updatedRaw != null ? DateTime.tryParse(updatedRaw) : null,
      area: json['area'] as String?,
      approxLocation: approxRaw is Map<String, dynamic>
          ? ApproxLocation.fromJson(approxRaw)
          : null,
    );
  }
}

class NearbyOwnersResponse {
  final int total;
  final int page;
  final int limit;
  final int radius;
  final NearbyCurrentUserLocation? currentUser;
  final List<NearbyClusterModel> clusters;
  final List<NearbyOwnerModel> owners;

  const NearbyOwnersResponse({
    required this.total,
    required this.page,
    required this.limit,
    required this.radius,
    this.currentUser,
    required this.clusters,
    required this.owners,
  });

  factory NearbyOwnersResponse.fromJson(Map<String, dynamic> json) {
    final currentUserRaw = json['currentUser'];
    final clustersList = json['clusters'] as List<dynamic>? ?? [];
    final ownersList = json['owners'] as List<dynamic>? ?? [];

    return NearbyOwnersResponse(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      radius: (json['radius'] as num?)?.toInt() ?? 10,
      currentUser: currentUserRaw is Map<String, dynamic>
          ? NearbyCurrentUserLocation.fromJson(currentUserRaw)
          : null,
      clusters: clustersList
          .whereType<Map<String, dynamic>>()
          .map(NearbyClusterModel.fromJson)
          .toList(),
      owners: ownersList
          .whereType<Map<String, dynamic>>()
          .map(NearbyOwnerModel.fromJson)
          .toList(),
    );
  }
}
