import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../domain/entities/chat_entities.dart';
import '../models/match_conversation_model.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

class ChatRepository {
  final ApiClient _apiClient;
  final FirebaseFirestore _firestore;

  ChatRepository(this._apiClient, this._firestore);

  // 1. PostgreSQL Matches List
  Future<List<MatchConversationModel>> getMatches() async {
    try {
      final response = await _apiClient.get('/matches');
      if (response is Map<String, dynamic> && response['matches'] is List) {
        return (response['matches'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => MatchConversationModel.fromJson(m))
            .toList();
      }
    } catch (_) {
      // Return empty list on failure; no mock demo data
    }
    return [];
  }

  // 2. Chat Access & Verification (PostgreSQL + Firestore repair)
  Future<Map<String, dynamic>> getMatchChat(String matchId) async {
    final response = await _apiClient.get('/matches/$matchId/chat');
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw Exception('Failed to get match chat');
  }

  // 3. Unmatch
  Future<void> unmatch(String matchId) async {
    await _apiClient.post('/matches/$matchId/unmatch', body: {});
  }

  // 4. Block User
  Future<void> blockUser(String userId) async {
    await _apiClient.post('/users/$userId/block', body: {});
  }

  // 5. Report Conversation / Message
  Future<void> reportChat(
    String conversationId, {
    String? messageId,
    required String reason,
  }) async {
    await _apiClient.post(
      '/chats/$conversationId/report',
      body: {
        if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
        'reason': reason,
      },
    );
  }

  // 6. Firestore Conversations Stream
  Stream<List<FirestoreConversation>> watchConversations(String myUid) {
    if (myUid.isEmpty) return Stream.value(<FirestoreConversation>[]);
    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FirestoreConversation.fromFirestore(d))
            .toList());
  }

  // 7. Single Conversation Stream
  Stream<FirestoreConversation?> watchConversation(String conversationId) {
    if (conversationId.isEmpty) {
      return Stream<FirestoreConversation?>.value(null);
    }
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) =>
            doc.exists ? FirestoreConversation.fromFirestore(doc) : null);
  }

  // 8. Messages Stream (Newest first, with limit)
  Stream<List<FirestoreMessage>> watchMessages(
    String conversationId, {
    int limit = 30,
  }) {
    if (conversationId.isEmpty) return Stream.value(<FirestoreMessage>[]);
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FirestoreMessage.fromFirestore(d))
            .toList());
  }

  // 9. Send Text Message (with optional reply)
  Future<void> sendMessage(
    String conversationId,
    String text,
    String myUid,
    String otherUid, {
    ReplyToData? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || myUid.isEmpty) return;
    if (trimmed.length > 1000) {
      throw Exception('Message cannot exceed 1000 characters');
    }

    final batch = _firestore.batch();
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final msgData = <String, dynamic>{
      'senderUid': myUid,
      'text': trimmed,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (replyTo != null) {
      msgData['replyTo'] = replyTo.toMap();
    }

    batch.set(msgRef, msgData);

    final Map<String, dynamic> convUpdate = {
      'lastMessage': {
        'text': trimmed,
        'senderUid': myUid,
        'type': 'text',
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
    };

    if (otherUid.isNotEmpty) {
      convUpdate['unread.$otherUid'] = FieldValue.increment(1);
    }

    batch.update(convRef, convUpdate);
    await batch.commit();
  }

  // 10. Mark Read
  Future<void> markRead(String conversationId, String myUid) async {
    if (conversationId.isEmpty || myUid.isEmpty) return;
    try {
      final convRef = _firestore.collection('conversations').doc(conversationId);
      await convRef.update({
        'unread.$myUid': 0,
        'lastRead.$myUid': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignored if document is not yet loaded or client is offline
    }
  }

  // 11. Delete for me (direct Firestore update — rules allow adding own uid)
  Future<void> deleteForMe(
    String conversationId,
    String messageId,
    String myUid,
  ) async {
    if (conversationId.isEmpty || messageId.isEmpty || myUid.isEmpty) return;
    final msgRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
    await msgRef.update({
      'deletedFor': FieldValue.arrayUnion([myUid]),
    });
  }

  // 12. Delete for everyone (via backend)
  Future<void> deleteForEveryone(
    String conversationId,
    String messageId,
  ) async {
    await _apiClient.delete(
      '/chats/$conversationId/messages/$messageId?scope=everyone',
    );
  }

  // 13. Request media upload signature from backend
  Future<Map<String, dynamic>> requestMediaSignature(
    String conversationId, {
    required String kind,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final response = await _apiClient.post(
      '/chats/$conversationId/media/signature',
      body: {
        'kind': kind,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
      },
    );
    if (response is Map<String, dynamic>) return response;
    throw Exception('Failed to get upload signature');
  }

  // 14. Create media message via backend
  Future<Map<String, dynamic>> createMediaMessage(
    String conversationId, {
    required String clientMessageId,
    required List<Map<String, dynamic>> items,
    String? caption,
    ReplyToData? replyTo,
  }) async {
    final response = await _apiClient.post(
      '/chats/$conversationId/messages/media',
      body: {
        'clientMessageId': clientMessageId,
        'items': items,
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
        if (replyTo != null) 'replyTo': replyTo.toMap(),
      },
    );
    if (response is Map<String, dynamic>) return response;
    throw Exception('Failed to create media message');
  }

  // 15. Get signed delivery URLs for media
  Future<Map<String, String>> getMediaUrls(
    String conversationId,
    List<String> publicIds, {
    List<Map<String, dynamic>>? items,
  }) async {
    if (publicIds.isEmpty && (items == null || items.isEmpty)) return {};
    final response = await _apiClient.post(
      '/chats/$conversationId/media/urls',
      body: {
        'publicIds': publicIds,
        'items': ?items,
      },
    );
    if (response is Map<String, dynamic>) {
      return response.map((k, v) => MapEntry(k, v.toString()));
    }
    throw Exception('Failed to get media URLs');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final firestore = ref.watch(firestoreProvider);
  return ChatRepository(apiClient, firestore);
});
