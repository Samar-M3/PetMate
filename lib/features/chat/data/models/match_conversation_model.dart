class MatchPetInfo {
  final String id;
  final String name;
  final String? breed;
  final String? species;
  final String? imageUrl;

  const MatchPetInfo({
    required this.id,
    required this.name,
    this.breed,
    this.species,
    this.imageUrl,
  });

  factory MatchPetInfo.fromJson(Map<String, dynamic> json) {
    return MatchPetInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pet',
      breed: json['breed'] as String?,
      species: json['species'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'breed': breed,
        'species': species,
        'imageUrl': imageUrl,
      };
}

class MatchOwnerInfo {
  final String id;
  final String name;
  final String? imageUrl;
  final String? location;

  const MatchOwnerInfo({
    required this.id,
    required this.name,
    this.imageUrl,
    this.location,
  });

  factory MatchOwnerInfo.fromJson(Map<String, dynamic> json) {
    return MatchOwnerInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pet Owner',
      imageUrl: json['imageUrl'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'location': location,
      };
}

class MatchConversationModel {
  final String matchId;
  final MatchPetInfo myPet;
  final MatchPetInfo otherPet;
  final MatchOwnerInfo otherOwner;
  final DateTime matchedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const MatchConversationModel({
    required this.matchId,
    required this.myPet,
    required this.otherPet,
    required this.otherOwner,
    required this.matchedAt,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = true,
  });

  factory MatchConversationModel.fromJson(Map<String, dynamic> json) {
    DateTime matchedDate = DateTime.now();
    if (json['matchedAt'] != null) {
      matchedDate =
          DateTime.tryParse(json['matchedAt'].toString()) ?? DateTime.now();
    }

    DateTime? lastMsgDate;
    if (json['lastMessageTime'] != null) {
      lastMsgDate = DateTime.tryParse(json['lastMessageTime'].toString());
    }

    return MatchConversationModel(
      matchId: json['matchId'] as String? ?? '',
      myPet: MatchPetInfo.fromJson(
        json['myPet'] as Map<String, dynamic>? ?? {},
      ),
      otherPet: MatchPetInfo.fromJson(
        json['otherPet'] as Map<String, dynamic>? ?? {},
      ),
      otherOwner: MatchOwnerInfo.fromJson(
        json['otherOwner'] as Map<String, dynamic>? ?? {},
      ),
      matchedAt: matchedDate,
      lastMessage: json['lastMessage'] as String? ?? '🐾 Matched! Say hello 👋',
      lastMessageTime: lastMsgDate ?? matchedDate,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isOnline: json['isOnline'] as bool? ?? true,
    );
  }

  MatchConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
  }) {
    return MatchConversationModel(
      matchId: matchId,
      myPet: myPet,
      otherPet: otherPet,
      otherOwner: otherOwner,
      matchedAt: matchedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isMine,
    this.isRead = true,
  });
}
