class SellerStoreModel {
  final String id;
  final String name;
  final String slug;
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED'
  final String businessType; // 'INDIVIDUAL' | 'REGISTERED_BUSINESS'
  final String? businessAddress;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? description;
  final String? registrationDocUrl;
  final String? identityDocUrl;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  const SellerStoreModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.businessType,
    this.businessAddress,
    this.city,
    this.province,
    this.postalCode,
    this.description,
    this.registrationDocUrl,
    this.identityDocUrl,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isSuspended => status == 'SUSPENDED';

  String get businessTypeLabel => businessType == 'REGISTERED_BUSINESS'
      ? 'Registered Business'
      : 'Individual Seller';

  factory SellerStoreModel.fromJson(Map<String, dynamic> json) {
    return SellerStoreModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      status: (json['status'] as String? ?? 'PENDING').toUpperCase(),
      businessType:
          (json['businessType'] as String? ??
                  json['business_type'] as String? ??
                  'INDIVIDUAL')
              .toUpperCase(),
      businessAddress:
          json['businessAddress'] as String? ??
          json['business_address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      postalCode:
          json['postalCode'] as String? ?? json['postal_code'] as String?,
      description: json['description'] as String?,
      registrationDocUrl:
          json['registrationDocUrl'] as String? ??
          json['registration_doc_url'] as String?,
      identityDocUrl:
          json['identityDocUrl'] as String? ??
          json['identity_doc_url'] as String?,
      rejectionReason:
          json['rejectionReason'] as String? ??
          json['rejection_reason'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString())
          : (json['submitted_at'] != null
                ? DateTime.tryParse(json['submitted_at'].toString())
                : null),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'].toString())
          : (json['reviewed_at'] != null
                ? DateTime.tryParse(json['reviewed_at'].toString())
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'status': status,
      'businessType': businessType,
      'businessAddress': businessAddress,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'description': description,
      'registrationDocUrl': registrationDocUrl,
      'identityDocUrl': identityDocUrl,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }
}

class SellerStatusResponseModel {
  final bool hasStore;
  final String applicationStatus; // 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED' | 'NOT_APPLIED'
  final String? sellerName;
  final String? email;
  final String? phoneNumber;
  final bool isActive;
  final SellerStoreModel? store;

  const SellerStatusResponseModel({
    required this.hasStore,
    required this.applicationStatus,
    this.sellerName,
    this.email,
    this.phoneNumber,
    this.isActive = true,
    this.store,
  });

  bool get isApproved =>
      applicationStatus == 'APPROVED' && (store?.isApproved ?? false);
  bool get isPending => applicationStatus == 'PENDING';
  bool get isRejected => applicationStatus == 'REJECTED';
  bool get isSuspended => applicationStatus == 'SUSPENDED' || !isActive;

  factory SellerStatusResponseModel.fromJson(Map<String, dynamic> json) {
    SellerStoreModel? storeModel;
    if (json['store'] != null && json['store'] is Map<String, dynamic>) {
      storeModel = SellerStoreModel.fromJson(
        json['store'] as Map<String, dynamic>,
      );
    }

    return SellerStatusResponseModel(
      hasStore: json['hasStore'] as bool? ?? (storeModel != null),
      applicationStatus:
          (json['applicationStatus'] as String? ??
                  storeModel?.status ??
                  'NOT_APPLIED')
              .toUpperCase(),
      sellerName: json['sellerName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      store: storeModel,
    );
  }
}

class SellerDashboardMetrics {
  final int totalProducts;
  final int totalOrders;
  final double totalRevenueNpr;

  const SellerDashboardMetrics({
    required this.totalProducts,
    required this.totalOrders,
    required this.totalRevenueNpr,
  });

  factory SellerDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return SellerDashboardMetrics(
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalRevenueNpr: (json['totalRevenueNpr'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SellerDashboardData {
  final SellerStoreModel store;
  final SellerDashboardMetrics metrics;

  const SellerDashboardData({required this.store, required this.metrics});

  factory SellerDashboardData.fromJson(Map<String, dynamic> json) {
    return SellerDashboardData(
      store: SellerStoreModel.fromJson(
        (json['store'] as Map<String, dynamic>?) ?? {},
      ),
      metrics: SellerDashboardMetrics.fromJson(
        (json['metrics'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}
