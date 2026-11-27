class AdminStatsModel {
  final int totalUsers;
  final Map<String, int> usersByRole;
  final int totalPets;
  final int totalOrders;
  final int totalAppointments;
  final double totalRevenue;
  final int pendingApplications;
  final int totalEvents;
  final int totalVeterinarians;
  final List<AdminRecentUser> recentUsers;
  final List<AdminRecentApplication> recentApplications;

  int get safeTotalEvents => totalEvents;
  int get safeTotalVeterinarians => totalVeterinarians;

  AdminStatsModel({
    required this.totalUsers,
    required this.usersByRole,
    required this.totalPets,
    required this.totalOrders,
    this.totalAppointments = 0,
    this.totalRevenue = 0.0,
    required this.pendingApplications,
    this.totalEvents = 0,
    this.totalVeterinarians = 0,
    this.recentUsers = const [],
    this.recentApplications = const [],
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double parseDouble(dynamic val) {
      if (val is double) return val;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final rawRoles = json['usersByRole'] as Map<String, dynamic>? ?? {};
    final rolesMap = <String, int>{};
    rawRoles.forEach((k, v) {
      rolesMap[k] = parseInt(v);
    });

    final recentUsersList =
        (json['recentUsers'] as List<dynamic>?)
            ?.map((u) => AdminRecentUser.fromJson(u as Map<String, dynamic>))
            .toList() ??
        [];

    final recentAppsList =
        (json['recentApplications'] as List<dynamic>?)
            ?.map(
              (a) => AdminRecentApplication.fromJson(a as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return AdminStatsModel(
      totalUsers: parseInt(json['totalUsers']),
      usersByRole: rolesMap,
      totalPets: parseInt(json['totalPets']),
      totalOrders: parseInt(json['totalOrders']),
      totalAppointments: parseInt(json['totalAppointments']),
      totalRevenue: parseDouble(json['totalRevenue']),
      pendingApplications: parseInt(json['pendingApplications']),
      totalEvents: parseInt(json['totalEvents']),
      totalVeterinarians: parseInt(json['totalVeterinarians']),
      recentUsers: recentUsersList,
      recentApplications: recentAppsList,
    );
  }
}

class AdminRecentUser {
  final String id;
  final String? email;
  final String? fullName;
  final String? imageUrl;
  final String role;
  final int petsCount;
  final DateTime? createdAt;

  const AdminRecentUser({
    required this.id,
    this.email,
    this.fullName,
    this.imageUrl,
    this.role = 'PET_OWNER',
    this.petsCount = 0,
    this.createdAt,
  });

  factory AdminRecentUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;
    return AdminRecentUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      fullName: profile?['fullName']?.toString(),
      imageUrl: profile?['imageUrl']?.toString(),
      role: json['role']?.toString() ?? 'PET_OWNER',
      petsCount: count?['pets'] is int ? count!['pets'] as int : 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class AdminRecentApplication {
  final String id;
  final String userId;
  final String type;
  final String status;
  final String? userFullName;
  final String? userEmail;
  final String? storeName;
  final DateTime? createdAt;

  const AdminRecentApplication({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    this.userFullName,
    this.userEmail,
    this.storeName,
    this.createdAt,
  });

  factory AdminRecentApplication.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final profile = user?['profile'] as Map<String, dynamic>?;
    final store = user?['store'] as Map<String, dynamic>?;

    return AdminRecentApplication(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SELLER',
      status: json['status']?.toString() ?? 'PENDING',
      userFullName: profile?['fullName']?.toString(),
      userEmail: user?['email']?.toString(),
      storeName: store?['name']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
