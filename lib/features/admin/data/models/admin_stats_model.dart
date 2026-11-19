class AdminStatsModel {
  final int totalUsers;
  final Map<String, int> usersByRole;
  final int totalPets;
  final int totalOrders;
  final int pendingApplications;

  AdminStatsModel({
    required this.totalUsers,
    required this.usersByRole,
    required this.totalPets,
    required this.totalOrders,
    required this.pendingApplications,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['usersByRole'] as Map<String, dynamic>? ?? {};
    final rolesMap = <String, int>{};
    rawRoles.forEach((k, v) {
      rolesMap[k] = (v is num) ? v.toInt() : 0;
    });

    return AdminStatsModel(
      totalUsers: json['totalUsers'] as int? ?? 0,
      usersByRole: rolesMap,
      totalPets: json['totalPets'] as int? ?? 0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      pendingApplications: json['pendingApplications'] as int? ?? 0,
    );
  }
}
