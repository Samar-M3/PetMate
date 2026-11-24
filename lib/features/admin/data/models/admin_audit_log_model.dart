class AdminAuditLogModel {
  final String id;
  final String? actorId;
  final String? targetId;
  final String action;
  final String? oldValue;
  final String? newValue;
  final String? notes;
  final DateTime createdAt;
  final String? actorEmail;
  final String? actorRole;
  final String? targetEmail;
  final String? targetRole;

  AdminAuditLogModel({
    required this.id,
    this.actorId,
    this.targetId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.notes,
    required this.createdAt,
    this.actorEmail,
    this.actorRole,
    this.targetEmail,
    this.targetRole,
  });

  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final target = json['target'] as Map<String, dynamic>?;

    return AdminAuditLogModel(
      id: json['id'] as String? ?? '',
      actorId: json['actorId'] as String?,
      targetId: json['targetId'] as String?,
      action: json['action'] as String? ?? 'UNKNOWN',
      oldValue: json['oldValue'] as String?,
      newValue: json['newValue'] as String?,
      notes: json['notes'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      actorEmail: actor?['email'] as String?,
      actorRole: actor?['role'] as String?,
      targetEmail: target?['email'] as String?,
      targetRole: target?['role'] as String?,
    );
  }
}
