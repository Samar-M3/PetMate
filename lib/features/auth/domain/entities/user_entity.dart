import 'user_role.dart';

class ProfileEntity {
  final String id;
  final String userId;
  final String? fullName;
  final String? profilePictureUrl;
  final String? imageUrl;
  final String? imagePublicId;
  final String? location;
  final String? area;
  final String? bio;

  const ProfileEntity({
    required this.id,
    required this.userId,
    this.fullName,
    this.profilePictureUrl,
    this.imageUrl,
    this.imagePublicId,
    this.location,
    this.area,
    this.bio,
  });

  String? get effectiveImageUrl => imageUrl ?? profilePictureUrl;
}

class PetEntity {
  final String id;
  final String userId;
  final String name;
  final String? profilePictureUrl;
  final String? imageUrl;
  final String? imagePublicId;
  final String? animalType;
  final String? breed;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? color;
  final List<String> personality;
  final String? vaccinationStatus;
  final String? allergies;
  final String? description;

  const PetEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.profilePictureUrl,
    this.imageUrl,
    this.imagePublicId,
    this.animalType,
    this.breed,
    this.gender,
    this.dateOfBirth,
    this.color,
    this.personality = const [],
    this.vaccinationStatus,
    this.allergies,
    this.description,
  });

  String? get effectiveImageUrl => imageUrl ?? profilePictureUrl;

  String get ageString {
    if (dateOfBirth == null) return 'Unknown age';
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    int months = now.month - dateOfBirth!.month;
    if (now.day < dateOfBirth!.day) {
      months--;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years <= 0 && months <= 0) {
      return 'Less than a month';
    }
    if (years <= 0) {
      return '$months ${months == 1 ? 'month' : 'months'} old';
    }
    if (months == 0) {
      return '$years ${years == 1 ? 'year' : 'years'} old';
    }
    return '$years yr $months mo old';
  }
}

class UserEntity {
  final String id;
  final String firebaseUid;
  final String? email;
  final String? phoneNumber;
  final UserRole role;
  final bool isActive;
  final bool onboardingCompleted;
  final ProfileEntity? profile;
  final List<PetEntity> pets;

  const UserEntity({
    required this.id,
    required this.firebaseUid,
    this.email,
    this.phoneNumber,
    this.role = UserRole.petOwner,
    this.isActive = true,
    this.onboardingCompleted = false,
    this.profile,
    this.pets = const [],
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isSeller => role == UserRole.seller;
  bool get isVeterinarian => role == UserRole.veterinarian;
}
