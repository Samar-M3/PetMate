class RoleApplicationModel {
  final String id;
  final String userId;
  final String type; // 'SELLER' | 'VETERINARIAN'
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final String? notes;
  final String? userEmail;
  final String? userFullName;
  final String? userImageUrl;
  final String? userLocation;
  final DateTime createdAt;

  RoleApplicationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    this.notes,
    this.userEmail,
    this.userFullName,
    this.userImageUrl,
    this.userLocation,
    required this.createdAt,
  });

  factory RoleApplicationModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final profile = user?['profile'] as Map<String, dynamic>?;

    return RoleApplicationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'SELLER',
      status: json['status'] as String? ?? 'PENDING',
      notes: json['notes'] as String?,
      userEmail: user?['email'] as String?,
      userFullName:
          profile?['fullName'] as String? ?? profile?['full_name'] as String?,
      userImageUrl:
          profile?['imageUrl'] as String? ?? profile?['image_url'] as String?,
      userLocation: profile?['location'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
