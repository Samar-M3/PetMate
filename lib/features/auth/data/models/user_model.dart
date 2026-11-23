import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.userId,
    super.fullName,
    super.profilePictureUrl,
    super.imageUrl,
    super.imagePublicId,
    super.location,
    super.area,
    super.bio,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final rawUrl =
        json['imageUrl'] as String? ??
        json['image_url'] as String? ??
        json['profilePictureUrl'] as String? ??
        json['profile_picture_url'] as String?;

    return ProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['full_name'] as String?,
      profilePictureUrl: rawUrl,
      imageUrl: rawUrl,
      imagePublicId:
          json['imagePublicId'] as String? ??
          json['image_public_id'] as String?,
      location: json['location'] as String?,
      area: json['area'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'profilePictureUrl': profilePictureUrl,
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
      'location': location,
      'area': area,
      'bio': bio,
    };
  }
}

class PetModel extends PetEntity {
  const PetModel({
    required super.id,
    required super.userId,
    required super.name,
    super.profilePictureUrl,
    super.imageUrl,
    super.imagePublicId,
    super.animalType,
    super.breed,
    super.gender,
    super.dateOfBirth,
    super.color,
    super.personality,
    super.vaccinationStatus,
    super.allergies,
    super.description,
    super.isActive = false,
    super.activatedAt,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    DateTime? dob;
    if (json['dateOfBirth'] != null) {
      dob = DateTime.tryParse(json['dateOfBirth'].toString());
    } else if (json['date_of_birth'] != null) {
      dob = DateTime.tryParse(json['date_of_birth'].toString());
    }

    List<String> persList = [];
    if (json['personality'] is List) {
      persList = (json['personality'] as List)
          .map((e) => e.toString())
          .toList();
    }

    final rawUrl =
        json['imageUrl'] as String? ??
        json['image_url'] as String? ??
        json['profilePictureUrl'] as String? ??
        json['profile_picture_url'] as String?;

    return PetModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profilePictureUrl: rawUrl,
      imageUrl: rawUrl,
      imagePublicId:
          json['imagePublicId'] as String? ??
          json['image_public_id'] as String?,
      animalType:
          json['animalType'] as String? ?? json['animal_type'] as String?,
      breed: json['breed'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: dob,
      color: json['color'] as String?,
      personality: persList,
      vaccinationStatus:
          json['vaccinationStatus'] as String? ??
          json['vaccination_status'] as String?,
      allergies: json['allergies'] as String?,
      description: json['description'] as String?,
      isActive:
          json['isActive'] as bool? ?? json['is_active'] as bool? ?? false,
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'].toString())
          : (json['activated_at'] != null
                ? DateTime.tryParse(json['activated_at'].toString())
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'profilePictureUrl': profilePictureUrl,
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
      'animalType': animalType,
      'breed': breed,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'color': color,
      'personality': personality,
      'vaccinationStatus': vaccinationStatus,
      'allergies': allergies,
      'description': description,
      'isActive': isActive,
      'activatedAt': activatedAt?.toIso8601String(),
    };
  }
}

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.firebaseUid,
    super.email,
    super.phoneNumber,
    super.role,
    super.isActive,
    super.onboardingCompleted,
    super.profile,
    super.pets,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? prof;
    if (json['profile'] != null && json['profile'] is Map) {
      prof = ProfileModel.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      );
    }

    List<PetModel> petsList = [];
    if (json['pets'] != null && json['pets'] is List) {
      petsList = (json['pets'] as List)
          .whereType<Map>()
          .map((p) => PetModel.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    return UserModel(
      id: json['id'] as String? ?? '',
      firebaseUid:
          json['firebaseUid'] as String? ??
          json['firebase_uid'] as String? ??
          '',
      email: json['email'] as String?,
      phoneNumber:
          json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      onboardingCompleted:
          json['onboardingCompleted'] as bool? ??
          json['onboarding_completed'] as bool? ??
          false,
      profile: prof,
      pets: petsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.toBackendString(),
      'isActive': isActive,
      'onboardingCompleted': onboardingCompleted,
      if (profile != null) 'profile': (profile as ProfileModel).toJson(),
      'pets': pets.map((p) => (p as PetModel).toJson()).toList(),
    };
  }
}
