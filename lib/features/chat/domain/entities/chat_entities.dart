import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreConversation {
  final String matchId;
  final List<String> participantUids;
  final String status; // 'ACTIVE' | 'ENDED'
  final String? endedReason;
  final DateTime? createdAt;
  final String? lastMessageText;
  final String? lastMessageSenderUid;
  final DateTime? lastMessageAt;
  final Map<String, int> unread;
  final Map<String, DateTime?> lastRead;

  const FirestoreConversation({
    required this.matchId,
    required this.participantUids,
    required this.status,
    this.endedReason,
    this.createdAt,
    this.lastMessageText,
    this.lastMessageSenderUid,
    this.lastMessageAt,
    this.unread = const {},
    this.lastRead = const {},
  });

  bool get isActive => status == 'ACTIVE';

  int unreadFor(String uid) => unread[uid] ?? 0;

  String otherUid(String myUid) =>
      participantUids.firstWhere((u) => u != myUid, orElse: () => '');

  factory FirestoreConversation.fromFirestore(
    DocumentSnapshot snapshot,
  ) {
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

    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return FirestoreConversation(
      matchId: snapshot.id,
      participantUids: (data['participantUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: data['status'] as String? ?? 'ACTIVE',
      endedReason: data['endedReason'] as String?,
      createdAt: parseTs(data['createdAt']),
      lastMessageText: lastMsg?['text'] as String?,
      lastMessageSenderUid: lastMsg?['senderUid'] as String?,
      lastMessageAt: parseTs(data['lastMessageAt']),
      unread: unread,
      lastRead: lastRead,
    );
  }
}

class FirestoreMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime createdAt;
  final bool isPending;

  const FirestoreMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
    this.isPending = false,
  });

  factory FirestoreMessage.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final ts = data['createdAt'];
    DateTime dt = DateTime.now();
    final bool pending = doc.metadata.hasPendingWrites;

    if (ts is Timestamp) {
      dt = ts.toDate();
    }

    return FirestoreMessage(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: dt,
      isPending: pending,
    );
  }
}
