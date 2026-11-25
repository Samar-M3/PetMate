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
  final Map<String, DateTime> _deliveredThrough = {};
  final Map<String, String> _seenThrough = {};
  final Set<String> _permissionDeniedReceipts = {};
  final Map<String, Future<bool>> _receiptWritesInFlight = {};

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
      // Return empty list on failure.
    }

    return [];
  }

  // 2. Chat Access & Verification
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
    if (myUid.isEmpty) {
      return Stream.value(<FirestoreConversation>[]);
    }

    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FirestoreConversation.fromFirestore(d))
              .toList(),
        );
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
        .map(
          (doc) => doc.exists ? FirestoreConversation.fromFirestore(doc) : null,
        );
  }

  // 8. Messages Stream
  Stream<List<FirestoreMessage>> watchMessages(
    String conversationId, {
    int limit = 30,
  }) {
    if (conversationId.isEmpty) {
      return Stream.value(<FirestoreMessage>[]);
    }

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => FirestoreMessage.fromFirestore(d)).toList(),
        );
  }

  // 9. Send Text Message
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

    // Only update fields allowed by the existing Firestore rules.
    // No deliveredAt, seenAt, or lastRead fields are written.
    final Map<String, dynamic> convUpdate = {
      'lastMessage': {'text': trimmed, 'senderUid': myUid, 'type': 'text'},
      'lastMessageAt': FieldValue.serverTimestamp(),
    };

    if (otherUid.isNotEmpty) {
      convUpdate['unread.$otherUid'] = FieldValue.increment(1);
    }

    batch.update(convRef, convUpdate);

    final messageId = msgRef.id;

    await batch.commit();

    // Trigger push notification in the background.
    // Notification failure must not block message sending.
    _apiClient
        .post(
          '/api/v1/chats/$conversationId/notify',
          body: {'messageId': messageId},
        )
        .catchError((_) => null);
  }

  // 10. Mark Read
  //
  // This only resets the unread counter.
  // It does not store a read timestamp or receipt.
  Future<void> markRead(String conversationId, String myUid) async {
    if (conversationId.isEmpty || myUid.isEmpty) return;

    try {
      final convRef = _firestore
          .collection('conversations')
          .doc(conversationId);

      await convRef.update({'unread.$myUid': 0});
    } on FirebaseException catch (error) {
      // Avoid crashing the chat UI if the write is rejected.
      if (error.code == 'permission-denied') {
        return;
      }
      return;
    } catch (_) {
      return;
    }
  }

  // 10b. Mark Delivered. The watermark advances only after a successful write.
  Future<bool> markDelivered(
    String conversationId,
    String myUid, {
    required DateTime lastMessageAt,
  }) async {
    if (conversationId.isEmpty || myUid.isEmpty) return false;
    final cacheKey = '$conversationId:$myUid';
    final previouslyDelivered = _deliveredThrough[cacheKey];
    if (previouslyDelivered != null &&
        !lastMessageAt.isAfter(previouslyDelivered)) {
      return true;
    }
    if (_permissionDeniedReceipts.contains(cacheKey)) return false;

    return _writeReceipt(
      key: 'delivered:$cacheKey',
      conversationKey: cacheKey,
      action: () async {
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update({'deliveredAt.$myUid': FieldValue.serverTimestamp()});
        _deliveredThrough[cacheKey] = lastMessageAt;
      },
    );
  }

  void clearReceiptPermissionError(String conversationId, String myUid) {
    if (conversationId.isEmpty || myUid.isEmpty) return;
    _permissionDeniedReceipts.remove('$conversationId:$myUid');
  }

  // 10c. Mark Seen and Read
  //
  // Read and seen watermarks advance once for each newly observed message,
  // or whenever forced (e.g. unread count is still > 0 on the conversation).
  Future<bool> markSeenAndRead(
    String conversationId,
    String myUid, {
    required String latestMessageId,
    bool includeSeenReceipt = true,
    bool force = false,
  }) async {
    if (conversationId.isEmpty || myUid.isEmpty || latestMessageId.isEmpty) {
      return false;
    }
    final cacheKey = '$conversationId:$myUid';
    if (!force && _seenThrough[cacheKey] == latestMessageId) return true;
    if (_permissionDeniedReceipts.contains(cacheKey)) return false;

    return _writeReceipt(
      key: 'seen:$cacheKey',
      conversationKey: cacheKey,
      action: () async {
        final updates = <String, dynamic>{
          'unread.$myUid': 0,
          'lastRead.$myUid': FieldValue.serverTimestamp(),
          if (includeSeenReceipt) 'seenAt.$myUid': FieldValue.serverTimestamp(),
        };
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update(updates);
        _seenThrough[cacheKey] = latestMessageId;
      },
    );
  }

  Future<bool> _writeReceipt({
    required String key,
    required String conversationKey,
    required Future<void> Function() action,
  }) async {
    final existing = _receiptWritesInFlight[key];
    if (existing != null) return existing;

    final write = _performReceiptWrite(conversationKey, action);
    _receiptWritesInFlight[key] = write;
    try {
      return await write;
    } finally {
      _receiptWritesInFlight.remove(key);
    }
  }

  Future<bool> _performReceiptWrite(
    String conversationKey,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _permissionDeniedReceipts.add(conversationKey);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // 11. Delete for Me
  // Firestore rules must allow the current participant to add
  // their own UID to deletedFor.
  Future<void> deleteForMe(
    String conversationId,
    String messageId,
    String myUid,
  ) async {
    if (conversationId.isEmpty || messageId.isEmpty || myUid.isEmpty) {
      return;
    }

    final msgRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    await msgRef.update({
      'deletedFor': FieldValue.arrayUnion([myUid]),
    });
  }

  // 12. Delete for Everyone
  Future<void> deleteForEveryone(
    String conversationId,
    String messageId,
  ) async {
    await _apiClient.delete(
      '/chats/$conversationId/messages/$messageId?scope=everyone',
    );
  }

  // 13. Batch Delete for Me
  Future<void> batchDeleteForMe(
    String conversationId,
    List<String> messageIds,
    String myUid,
  ) async {
    if (conversationId.isEmpty || messageIds.isEmpty || myUid.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final id in messageIds) {
      final ref = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(id);

      batch.update(ref, {
        'deletedFor': FieldValue.arrayUnion([myUid]),
      });
    }

    await batch.commit();
  }

  // 14. Batch Delete for Everyone
  Future<Map<String, dynamic>> batchDeleteForEveryone(
    String conversationId,
    List<String> messageIds,
  ) async {
    final response = await _apiClient.post(
      '/chats/$conversationId/messages/delete',
      body: {'messageIds': messageIds, 'scope': 'everyone'},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception('Failed to batch delete messages');
  }

  // 15. Request Media Upload Signature
  Future<Map<String, dynamic>> requestMediaSignature(
    String conversationId, {
    required String kind,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final response = await _apiClient.post(
      '/chats/$conversationId/media/signature',
      body: {'kind': kind, 'mimeType': mimeType, 'sizeBytes': sizeBytes},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception('Failed to get upload signature');
  }

  // 16. Create Media Message
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

    if (response is Map<String, dynamic>) {
      final messageId =
          response['messageId'] ??
          response['data']?['messageId'] ??
          clientMessageId;

      _apiClient
          .post(
            '/api/v1/chats/$conversationId/notify',
            body: {'messageId': messageId},
          )
          .catchError((_) => null);

      return response;
    }

    throw Exception('Failed to create media message');
  }

  // 17. Get Signed Media URLs
  Future<Map<String, String>> getMediaUrls(
    String conversationId,
    List<String> publicIds, {
    List<Map<String, dynamic>>? items,
  }) async {
    if (publicIds.isEmpty && (items == null || items.isEmpty)) {
      return {};
    }

    final response = await _apiClient.post(
      '/chats/$conversationId/media/urls',
      body: {'publicIds': publicIds, 'items': ?items},
    );

    if (response is Map<String, dynamic>) {
      return response.map((key, value) => MapEntry(key, value.toString()));
    }

    throw Exception('Failed to get media URLs');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final firestore = ref.watch(firestoreProvider);

  return ChatRepository(apiClient, firestore);
});
