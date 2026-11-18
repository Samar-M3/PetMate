/// Mirrors the backend Prisma `Role` enum.
/// Default is [petOwner] — always fall back to this for unknown strings.
enum UserRole {
  petOwner,
  seller,
  veterinarian,
  admin;

  /// Parse a backend role string (e.g. "PET_OWNER", "ADMIN") to [UserRole].
  /// Unknown values default to [petOwner] for safety.
  static UserRole fromString(String? value) {
    if (value == null) return UserRole.petOwner;
    switch (value.toUpperCase()) {
      case 'PET_OWNER':
        return UserRole.petOwner;
      case 'SELLER':
        return UserRole.seller;
      case 'VETERINARIAN':
        return UserRole.veterinarian;
      case 'ADMIN':
        return UserRole.admin;
      default:
        return UserRole.petOwner;
    }
  }

  /// Convert to the backend enum string (e.g. "PET_OWNER").
  String toBackendString() {
    switch (this) {
      case UserRole.petOwner:
        return 'PET_OWNER';
      case UserRole.seller:
        return 'SELLER';
      case UserRole.veterinarian:
        return 'VETERINARIAN';
      case UserRole.admin:
        return 'ADMIN';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.petOwner:
        return 'Pet Owner';
      case UserRole.seller:
        return 'Seller';
      case UserRole.veterinarian:
        return 'Veterinarian';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
