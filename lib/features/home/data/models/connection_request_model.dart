class ConnectionRequestModel {
  final String id;
  final String senderUserId;
  final String senderUsername;
  final String senderPetId;
  final String senderPetName;
  final String? senderPetImageUrl;
  final String senderPetBreed;
  final String receiverPetId;
  final String receiverPetName;
  final String status;
  final DateTime? createdAt;

  const ConnectionRequestModel({
    required this.id,
    required this.senderUserId,
    required this.senderUsername,
    required this.senderPetId,
    required this.senderPetName,
    this.senderPetImageUrl,
    required this.senderPetBreed,
    required this.receiverPetId,
    required this.receiverPetName,
    this.status = 'PENDING',
    this.createdAt,
  });

  factory ConnectionRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String);
      }
    }

    return ConnectionRequestModel(
      id: json['id'] as String? ?? '',
      senderUserId: json['senderUserId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? 'Pet Parent',
      senderPetId: json['senderPetId'] as String? ?? '',
      senderPetName: json['senderPetName'] as String? ?? 'Pet',
      senderPetImageUrl: json['senderPetImageUrl'] as String?,
      senderPetBreed: json['senderPetBreed'] as String? ?? '',
      receiverPetId: json['receiverPetId'] as String? ?? '',
      receiverPetName: json['receiverPetName'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderUserId': senderUserId,
      'senderUsername': senderUsername,
      'senderPetId': senderPetId,
      'senderPetName': senderPetName,
      'senderPetImageUrl': senderPetImageUrl,
      'senderPetBreed': senderPetBreed,
      'receiverPetId': receiverPetId,
      'receiverPetName': receiverPetName,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class IncomingRequestsResult {
  final List<ConnectionRequestModel> requests;
  final String? nextCursor;
  final bool hasMore;
  final int pendingCount;

  const IncomingRequestsResult({
    required this.requests,
    this.nextCursor,
    required this.hasMore,
    required this.pendingCount,
  });

  factory IncomingRequestsResult.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['requests'] as List<dynamic>? ?? [];
    final requests = rawRequests
        .whereType<Map<String, dynamic>>()
        .map((r) => ConnectionRequestModel.fromJson(r))
        .toList();

    return IncomingRequestsResult(
      requests: requests,
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
      pendingCount: json['pendingCount'] as int? ?? requests.length,
    );
  }
}
