class ConnectionRequestModel {
  final String id;
  final String senderUserId;
  final String senderUsername;
  final String? senderOwnerImageUrl;
  final String senderPetId;
  final String senderPetName;
  final String? senderPetImageUrl;
  final String senderPetBreed;
  final String senderPetSpecies;
  final String receiverPetId;
  final String receiverPetName;
  final String? receiverPetImageUrl;
  final String? initialMessage;
  final DateTime? initialMessageAt;
  final String status;
  final DateTime? createdAt;

  const ConnectionRequestModel({
    required this.id,
    required this.senderUserId,
    required this.senderUsername,
    this.senderOwnerImageUrl,
    required this.senderPetId,
    required this.senderPetName,
    this.senderPetImageUrl,
    required this.senderPetBreed,
    this.senderPetSpecies = '',
    required this.receiverPetId,
    required this.receiverPetName,
    this.receiverPetImageUrl,
    this.initialMessage,
    this.initialMessageAt,
    this.status = 'PENDING',
    this.createdAt,
  });

  bool get hasInitialMessage =>
      initialMessage != null && initialMessage!.trim().isNotEmpty;

  factory ConnectionRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String);
    }

    DateTime? parsedInitialMessageAt;
    if (json['initialMessageAt'] is String) {
      parsedInitialMessageAt =
          DateTime.tryParse(json['initialMessageAt'] as String);
    }

    return ConnectionRequestModel(
      id: json['id'] as String? ?? '',
      senderUserId: json['senderUserId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? 'Pet Parent',
      senderOwnerImageUrl: json['senderOwnerImageUrl'] as String?,
      senderPetId: json['senderPetId'] as String? ?? '',
      senderPetName: json['senderPetName'] as String? ?? 'Pet',
      senderPetImageUrl: json['senderPetImageUrl'] as String?,
      senderPetBreed: json['senderPetBreed'] as String? ?? '',
      senderPetSpecies: json['senderPetSpecies'] as String? ?? '',
      receiverPetId: json['receiverPetId'] as String? ?? '',
      receiverPetName: json['receiverPetName'] as String? ?? '',
      receiverPetImageUrl: json['receiverPetImageUrl'] as String?,
      initialMessage: json['initialMessage'] as String?,
      initialMessageAt: parsedInitialMessageAt,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderUserId': senderUserId,
      'senderUsername': senderUsername,
      'senderOwnerImageUrl': senderOwnerImageUrl,
      'senderPetId': senderPetId,
      'senderPetName': senderPetName,
      'senderPetImageUrl': senderPetImageUrl,
      'senderPetBreed': senderPetBreed,
      'senderPetSpecies': senderPetSpecies,
      'receiverPetId': receiverPetId,
      'receiverPetName': receiverPetName,
      'receiverPetImageUrl': receiverPetImageUrl,
      'initialMessage': initialMessage,
      'initialMessageAt': initialMessageAt?.toIso8601String(),
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

class OutgoingRequestModel {
  final String id;
  final String senderPetId;
  final String senderPetName;
  final String? senderPetImageUrl;
  final String receiverUserId;
  final String receiverOwnerName;
  final String? receiverOwnerImageUrl;
  final String receiverPetId;
  final String receiverPetName;
  final String receiverPetBreed;
  final String receiverPetSpecies;
  final String? receiverPetImageUrl;
  final String? initialMessage;
  final DateTime? initialMessageAt;
  final String status; // PENDING | ACCEPTED | DECLINED | REJECTED | EXPIRED | CANCELLED
  final String? matchId;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? cancelledAt;

  const OutgoingRequestModel({
    required this.id,
    required this.senderPetId,
    required this.senderPetName,
    this.senderPetImageUrl,
    required this.receiverUserId,
    required this.receiverOwnerName,
    this.receiverOwnerImageUrl,
    required this.receiverPetId,
    required this.receiverPetName,
    this.receiverPetBreed = '',
    this.receiverPetSpecies = '',
    this.receiverPetImageUrl,
    this.initialMessage,
    this.initialMessageAt,
    required this.status,
    this.matchId,
    this.createdAt,
    this.respondedAt,
    this.cancelledAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get hasInitialMessage =>
      initialMessage != null && initialMessage!.trim().isNotEmpty;

  factory OutgoingRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;

    return OutgoingRequestModel(
      id: json['id'] as String? ?? '',
      senderPetId: json['senderPetId'] as String? ?? '',
      senderPetName: json['senderPetName'] as String? ?? 'My Pet',
      senderPetImageUrl: json['senderPetImageUrl'] as String?,
      receiverUserId: json['receiverUserId'] as String? ?? '',
      receiverOwnerName: json['receiverOwnerName'] as String? ?? 'Pet Parent',
      receiverOwnerImageUrl: json['receiverOwnerImageUrl'] as String?,
      receiverPetId: json['receiverPetId'] as String? ?? '',
      receiverPetName: json['receiverPetName'] as String? ?? 'Pet',
      receiverPetBreed: json['receiverPetBreed'] as String? ?? '',
      receiverPetSpecies: json['receiverPetSpecies'] as String? ?? '',
      receiverPetImageUrl: json['receiverPetImageUrl'] as String?,
      initialMessage: json['initialMessage'] as String?,
      initialMessageAt: parseDt(json['initialMessageAt']),
      status: json['status'] as String? ?? 'PENDING',
      matchId: json['matchId'] as String?,
      createdAt: parseDt(json['createdAt']),
      respondedAt: parseDt(json['respondedAt']),
      cancelledAt: parseDt(json['cancelledAt']),
    );
  }

  OutgoingRequestModel copyWith({
    String? initialMessage,
    DateTime? initialMessageAt,
    String? status,
    DateTime? cancelledAt,
  }) {
    return OutgoingRequestModel(
      id: id,
      senderPetId: senderPetId,
      senderPetName: senderPetName,
      senderPetImageUrl: senderPetImageUrl,
      receiverUserId: receiverUserId,
      receiverOwnerName: receiverOwnerName,
      receiverOwnerImageUrl: receiverOwnerImageUrl,
      receiverPetId: receiverPetId,
      receiverPetName: receiverPetName,
      receiverPetBreed: receiverPetBreed,
      receiverPetSpecies: receiverPetSpecies,
      receiverPetImageUrl: receiverPetImageUrl,
      initialMessage: initialMessage ?? this.initialMessage,
      initialMessageAt: initialMessageAt ?? this.initialMessageAt,
      status: status ?? this.status,
      matchId: matchId,
      createdAt: createdAt,
      respondedAt: respondedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}

class OutgoingRequestsResult {
  final List<OutgoingRequestModel> requests;
  final String? nextCursor;
  final bool hasMore;

  const OutgoingRequestsResult({
    required this.requests,
    this.nextCursor,
    required this.hasMore,
  });

  factory OutgoingRequestsResult.fromJson(Map<String, dynamic> json) {
    final raw = json['requests'] as List<dynamic>? ?? [];
    final requests = raw
        .whereType<Map<String, dynamic>>()
        .map((r) => OutgoingRequestModel.fromJson(r))
        .toList();

    return OutgoingRequestsResult(
      requests: requests,
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
