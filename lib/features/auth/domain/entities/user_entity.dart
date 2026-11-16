class UserEntity {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;
  final String status;
  final String? profileImage;
  final String? address;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
    required this.status,
    this.profileImage,
    this.address,
  });
}
