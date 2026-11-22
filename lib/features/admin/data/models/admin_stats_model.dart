class AdminStatsModel {
  final int totalUsers;
  final Map<String, int> usersByRole;
  final int totalPets;
  final int totalOrders;
  final int pendingApplications;
  final int? totalEvents;
  final int? totalVeterinarians;

  int get safeTotalEvents => totalEvents ?? 0;
  int get safeTotalVeterinarians => totalVeterinarians ?? 0;

  AdminStatsModel({
    required this.totalUsers,
    required this.usersByRole,
    required this.totalPets,
    required this.totalOrders,
    required this.pendingApplications,
    this.totalEvents = 0,
    this.totalVeterinarians = 0,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    final rawRoles = json['usersByRole'] as Map<String, dynamic>? ?? {};
    final rolesMap = <String, int>{};
    rawRoles.forEach((k, v) {
      rolesMap[k] = parseInt(v);
    });

    return AdminStatsModel(
      totalUsers: parseInt(json['totalUsers']),
      usersByRole: rolesMap,
      totalPets: parseInt(json['totalPets']),
      totalOrders: parseInt(json['totalOrders']),
      pendingApplications: parseInt(json['pendingApplications']),
      totalEvents: parseInt(json['totalEvents']),
      totalVeterinarians: parseInt(json['totalVeterinarians']),
    );
  }
}
