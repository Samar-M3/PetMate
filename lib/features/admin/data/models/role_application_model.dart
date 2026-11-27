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

  // Seller store specific fields
  final String? storeName;
  final String? storeSlug;
  final String? businessType;
  final String? businessAddress;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? registrationDocUrl;
  final String? identityDocUrl;
  final String? storeStatus;
  final String? rejectionReason;

  // Veterinarian clinic specific fields
  final String? clinicName;
  final String? licenseNumber;
  final String? storeDescription;

  // Verification documents
  final String? govIdUrl;
  final String? taxDocumentUrl;
  final String? medicalLicenseUrl;

  // Admin notes
  final String? adminNotes;

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
    this.storeName,
    this.storeSlug,
    this.businessType,
    this.businessAddress,
    this.city,
    this.province,
    this.postalCode,
    this.registrationDocUrl,
    this.identityDocUrl,
    this.storeStatus,
    this.rejectionReason,
    this.clinicName,
    this.licenseNumber,
    this.storeDescription,
    this.govIdUrl,
    this.taxDocumentUrl,
    this.medicalLicenseUrl,
    this.adminNotes,
  });

  factory RoleApplicationModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final profile = user?['profile'] as Map<String, dynamic>?;
    final store = user?['store'] as Map<String, dynamic>?;

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
      storeName: store?['name'] as String?,
      storeSlug: store?['slug'] as String?,
      businessType:
          store?['businessType'] as String? ??
          store?['business_type'] as String?,
      businessAddress:
          store?['businessAddress'] as String? ??
          store?['business_address'] as String?,
      city: store?['city'] as String?,
      province: store?['province'] as String?,
      postalCode:
          store?['postalCode'] as String? ?? store?['postal_code'] as String?,
      registrationDocUrl:
          store?['registrationDocUrl'] as String? ??
          store?['registration_doc_url'] as String?,
      identityDocUrl:
          store?['identityDocUrl'] as String? ??
          store?['identity_doc_url'] as String?,
      storeStatus: store?['status'] as String?,
      rejectionReason:
          store?['rejectionReason'] as String? ??
          store?['rejection_reason'] as String?,
    );
  }
}
