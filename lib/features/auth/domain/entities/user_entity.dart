import 'user_role.dart';

class ProfileEntity {
  final String id;
  final String userId;
  final String? fullName;
  final String? profilePictureUrl;
  final String? location;
  final String? area;
  final String? bio;

  const ProfileEntity({
    required this.id,
    required this.userId,
    this.fullName,
    this.profilePictureUrl,
    this.location,
    this.area,
    this.bio,
  });

  String? get effectiveImageUrl => profilePictureUrl;
}

class PetEntity {
  final String id;
  final String userId;
  final String name;
  final String? profilePictureUrl;
  final String? animalType;
  final String? breed;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? color;
  final List<String> personality;
  final String? vaccinationStatus;
  final String? allergies;
  final String? description;
  final bool isActive;

  const PetEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.profilePictureUrl,
    this.animalType,
    this.breed,
    this.gender,
    this.dateOfBirth,
    this.color,
    this.personality = const [],
    this.vaccinationStatus,
    this.allergies,
    this.description,
    this.isActive = true,
  });

  String? get effectiveImageUrl => profilePictureUrl;

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
  final bool onboardingCompleted;
  final UserRole role;
  final ProfileEntity? profile;
  final List<PetEntity> pets;

  const UserEntity({
    required this.id,
    required this.firebaseUid,
    this.email,
    this.phoneNumber,
    this.onboardingCompleted = false,
    this.role = UserRole.petOwner,
    this.profile,
    this.pets = const [],
  });
}
