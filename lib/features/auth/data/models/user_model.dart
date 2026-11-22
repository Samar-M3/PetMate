import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.userId,
    super.fullName,
    super.profilePictureUrl,
    super.location,
    super.area,
    super.bio,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['full_name'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String? ?? json['profile_picture_url'] as String?,
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
    super.animalType,
    super.breed,
    super.gender,
    super.dateOfBirth,
    super.color,
    super.personality,
    super.vaccinationStatus,
    super.allergies,
    super.description,
    super.isActive = true,
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
      persList = (json['personality'] as List).map((e) => e.toString()).toList();
    }

    return PetModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profilePictureUrl: json['profilePictureUrl'] as String? ?? json['profile_picture_url'] as String?,
      animalType: json['animalType'] as String? ?? json['animal_type'] as String?,
      breed: json['breed'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: dob,
      color: json['color'] as String?,
      personality: persList,
      vaccinationStatus: json['vaccinationStatus'] as String? ?? json['vaccination_status'] as String?,
      allergies: json['allergies'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'profilePictureUrl': profilePictureUrl,
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
    };
  }
}

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.firebaseUid,
    super.email,
    super.phoneNumber,
    super.onboardingCompleted,
    super.role = UserRole.petOwner,
    super.profile,
    super.pets,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? prof;
    if (json['profile'] != null && json['profile'] is Map<String, dynamic>) {
      prof = ProfileModel.fromJson(json['profile'] as Map<String, dynamic>);
    }

    List<PetModel> petsList = [];
    if (json['pets'] != null && json['pets'] is List) {
      petsList = (json['pets'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => PetModel.fromJson(p))
          .toList();
    }

    return UserModel(
      id: json['id'] as String? ?? '',
      firebaseUid: json['firebaseUid'] as String? ?? json['firebase_uid'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ??
          json['onboarding_completed'] as bool? ??
          false,
      role: UserRole.fromString(json['role'] as String?),
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
      'onboardingCompleted': onboardingCompleted,
      'role': role.toBackendString(),
      if (profile != null) 'profile': (profile as ProfileModel).toJson(),
      'pets': pets.map((p) => (p as PetModel).toJson()).toList(),
    };
  }
}
