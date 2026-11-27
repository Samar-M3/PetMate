class AdminUserModel {
  final String id;
  final String? email;
  final String? phoneNumber;
  final String role;
  final bool isActive;
  final bool onboardingCompleted;
  final String? fullName;
  final String? imageUrl;
  final int petsCount;
  final DateTime createdAt;
  // For veterinarian records from Veterinarian table (not User table)
  final bool isVeterinarianRecord;
  final Map<String, dynamic>? veterinarianData;

  AdminUserModel({
    required this.id,
    this.email,
    this.phoneNumber,
    required this.role,
    required this.isActive,
    required this.onboardingCompleted,
    this.fullName,
    this.imageUrl,
    required this.petsCount,
    required this.createdAt,
    this.isVeterinarianRecord = false,
    this.veterinarianData,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;

    return AdminUserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber:
          json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      role: json['role'] as String? ?? 'PET_OWNER',
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      onboardingCompleted:
          json['onboardingCompleted'] as bool? ??
          json['onboarding_completed'] as bool? ??
          false,
      fullName:
          profile?['fullName'] as String? ?? profile?['full_name'] as String?,
      imageUrl:
          profile?['imageUrl'] as String? ?? profile?['image_url'] as String?,
      petsCount: count?['pets'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isVeterinarianRecord: json['isVeterinarianRecord'] as bool? ?? false,
      veterinarianData: json['veterinarianData'] as Map<String, dynamic>?,
    );
  }

  // Helper to get clinic name for veterinarian records
  String? get clinicName => veterinarianData?['clinicName'] as String?;
  
  // Helper to get specialty for veterinarian records
  String? get specialty => veterinarianData?['specialty'] as String?;
  
  // Helper to get address for veterinarian records
  String? get address => veterinarianData?['address'] as String?;
  
  // Helper to get fee for veterinarian records
  int? get fee => veterinarianData?['fee'] as int?;
  
  // Helper to get isVerified for veterinarian records
  bool get isVerified => veterinarianData?['isVerified'] == true;
  
  // Helper to get isAcceptingBookings for veterinarian records
  bool get isAcceptingBookings => veterinarianData?['isAcceptingBookings'] == true;
}
