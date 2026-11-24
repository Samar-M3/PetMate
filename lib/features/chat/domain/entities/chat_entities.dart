import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Message Status Ticks
// ---------------------------------------------------------------------------

enum MessageStatus {
  pending('Pending'),
  sent('Sent'),
  delivered('Delivered'),
  read('Read'),
  failed('Failed');

  final String label;
  const MessageStatus(this.label);
}

/// Computes the delivery and read status of a sent message.
MessageStatus computeMessageStatus({
  required FirestoreMessage message,
  required FirestoreConversation? conversation,
  required String myUid,
  required String otherUid,
  bool readReceiptsEnabled = true,
}) {
  if (message.senderUid != myUid) {
    return MessageStatus.sent;
  }

  if (message.id.startsWith('temp_') || message.id.startsWith('pending_')) {
    return MessageStatus.pending;
  }

  if (conversation == null) {
    return MessageStatus.sent;
  }

  if (readReceiptsEnabled) {
    final otherSeen = conversation.seenAtFor(otherUid);
    if (otherSeen != null && !message.createdAt.isAfter(otherSeen)) {
      return MessageStatus.read;
    }
  }

  final otherDelivered = conversation.deliveredAtFor(otherUid);
  if (otherDelivered != null && !message.createdAt.isAfter(otherDelivered)) {
    return MessageStatus.delivered;
  }

  return MessageStatus.sent;
}

// ---------------------------------------------------------------------------
// Reply-To snapshot stored with a message
// ---------------------------------------------------------------------------

class ReplyToData {
  final String messageId;
  final String senderUid;
  final String type;
  final String preview;

  const ReplyToData({
    required this.messageId,
    required this.senderUid,
    required this.type,
    required this.preview,
  });

  factory ReplyToData.fromMap(Map<String, dynamic> map) {
    return ReplyToData(
      messageId: map['messageId'] as String? ?? '',
      senderUid: map['senderUid'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      preview: map['preview'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderUid': senderUid,
    'type': type,
    'preview': preview,
  };
}

// ---------------------------------------------------------------------------
// Media item within a media message
// ---------------------------------------------------------------------------

class MediaItem {
  final String kind; // 'image' | 'video'
  final String publicId;
  final String format;
  final int bytes;
  final int width;
  final int height;
  final double? durationSeconds;
  final String? thumbnailPublicId;

  const MediaItem({
    required this.kind,
    required this.publicId,
    required this.format,
    required this.bytes,
    required this.width,
    required this.height,
    this.durationSeconds,
    this.thumbnailPublicId,
  });

  bool get isVideo => kind == 'video';
  bool get isImage => kind == 'image';

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      kind: map['kind'] as String? ?? 'image',
      publicId: map['publicId'] as String? ?? '',
      format: map['format'] as String? ?? '',
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble(),
      thumbnailPublicId: map['thumbnailPublicId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind,
    'publicId': publicId,
    'format': format,
    'bytes': bytes,
    'width': width,
    'height': height,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (thumbnailPublicId != null) 'thumbnailPublicId': thumbnailPublicId,
  };
}

// ---------------------------------------------------------------------------
// Firestore Conversation Document
// ---------------------------------------------------------------------------

class FirestoreConversation {
  final String matchId;
  final List<String> participantUids;
  final String status; // 'ACTIVE' | 'ENDED'
  final String? endedReason;
  final DateTime? createdAt;
  final String? lastMessageText;
  final String? lastMessageSenderUid;
  final String? lastMessageType; // 'text' | 'media'
  final DateTime? lastMessageAt;
  final Map<String, int> unread;
  final Map<String, DateTime?> lastRead;
  final Map<String, DateTime?> deliveredAt;
  final Map<String, DateTime?> seenAt;

  const FirestoreConversation({
    required this.matchId,
    required this.participantUids,
    required this.status,
    this.endedReason,
    this.createdAt,
    this.lastMessageText,
    this.lastMessageSenderUid,
    this.lastMessageType,
    this.lastMessageAt,
    this.unread = const {},
    this.lastRead = const {},
    this.deliveredAt = const {},
    this.seenAt = const {},
  });

  bool get isActive => status == 'ACTIVE';

  int unreadFor(String uid) => unread[uid] ?? 0;

  DateTime? deliveredAtFor(String uid) => deliveredAt[uid];
  DateTime? seenAtFor(String uid) => seenAt[uid];

  String otherUid(String myUid) =>
      participantUids.firstWhere((u) => u != myUid, orElse: () => '');

  factory FirestoreConversation.fromFirestore(DocumentSnapshot snapshot) {
    final data = (snapshot.data() as Map<String, dynamic>?) ?? {};
    final lastMsg = data['lastMessage'] as Map<String, dynamic>?;
    final rawUnread = data['unread'] as Map<String, dynamic>? ?? {};
    final unread = rawUnread.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );

    final rawLastRead = data['lastRead'] as Map<String, dynamic>? ?? {};
    final lastRead = rawLastRead.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate());
      return MapEntry(k, null);
    });

    final rawDeliveredAt = data['deliveredAt'] as Map<String, dynamic>? ?? {};
    final deliveredAt = rawDeliveredAt.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate());
      return MapEntry(k, null);
    });

    final rawSeenAt = data['seenAt'] as Map<String, dynamic>? ?? {};
    final seenAt = rawSeenAt.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate());
      return MapEntry(k, null);
    });

    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return FirestoreConversation(
      matchId: snapshot.id,
      participantUids:
          (data['participantUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: data['status'] as String? ?? 'ACTIVE',
      endedReason: data['endedReason'] as String?,
      createdAt: parseTs(data['createdAt']),
      lastMessageText: lastMsg?['text'] as String?,
      lastMessageSenderUid: lastMsg?['senderUid'] as String?,
      lastMessageType: lastMsg?['type'] as String?,
      lastMessageAt: parseTs(data['lastMessageAt']),
      unread: unread,
      lastRead: lastRead,
      deliveredAt: deliveredAt,
      seenAt: seenAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Firestore Message Document
// ---------------------------------------------------------------------------

class FirestoreMessage {
  final String id;
  final String senderUid;
  final String text;
  final String type; // 'text' | 'media'
  final DateTime createdAt;
  final bool isPending;
  final ReplyToData? replyTo;
  final List<MediaItem> media;
  final bool deletedForEveryone;
  final DateTime? deletedAt;
  final List<String> deletedFor;
  final bool mediaExpired;

  const FirestoreMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.isPending = false,
    this.replyTo,
    this.media = const [],
    this.deletedForEveryone = false,
    this.deletedAt,
    this.deletedFor = const [],
    this.mediaExpired = false,
  });

  bool get isMedia => type == 'media';
  bool get isText => type == 'text';

  /// Whether the message is deleted for a specific user.
  bool isDeletedFor(String uid) => deletedFor.contains(uid);

  /// Whether the message should be shown as "deleted" (either for everyone or for me).
  bool isVisiblyDeleted(String myUid) =>
      deletedForEveryone || deletedFor.contains(myUid);

  factory FirestoreMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final ts = data['createdAt'];
    DateTime dt = DateTime.now();
    final bool pending = doc.metadata.hasPendingWrites;

    if (ts is Timestamp) {
      dt = ts.toDate();
    }

    // Parse replyTo
    ReplyToData? replyTo;
    if (data['replyTo'] is Map<String, dynamic>) {
      replyTo = ReplyToData.fromMap(data['replyTo'] as Map<String, dynamic>);
    }

    // Parse media items
    List<MediaItem> media = const [];
    if (data['media'] is List) {
      media = (data['media'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => MediaItem.fromMap(m))
          .toList();
    }

    // Parse deletedFor
    List<String> deletedFor = const [];
    if (data['deletedFor'] is List) {
      deletedFor = (data['deletedFor'] as List)
          .map((e) => e.toString())
          .toList();
    }

    // Parse deletedAt
    DateTime? deletedAt;
    final rawDeletedAt = data['deletedAt'];
    if (rawDeletedAt is Timestamp) {
      deletedAt = rawDeletedAt.toDate();
    }

    return FirestoreMessage(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      createdAt: dt,
      isPending: pending,
      replyTo: replyTo,
      media: media,
      deletedForEveryone: data['deletedForEveryone'] as bool? ?? false,
      deletedAt: deletedAt,
      deletedFor: deletedFor,
      mediaExpired: data['mediaExpired'] as bool? ?? false,
    );
  }
}
