import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/features/chat/domain/entities/chat_entities.dart';

void main() {
  const myUid = 'user_me';
  const otherUid = 'user_other';
  final now = DateTime(2026, 11, 23, 10, 0, 0);

  FirestoreMessage createMsg({
    required String id,
    required String senderUid,
    required DateTime createdAt,
  }) {
    return FirestoreMessage(
      id: id,
      senderUid: senderUid,
      text: 'Test message',
      createdAt: createdAt,
    );
  }

  FirestoreConversation createConv({
    DateTime? otherDeliveredAt,
    DateTime? otherSeenAt,
  }) {
    return FirestoreConversation(
      matchId: 'match_123',
      participantUids: const [myUid, otherUid],
      status: 'ACTIVE',
      deliveredAt: {
        otherUid: ?otherDeliveredAt,
      },
      seenAt: {
        otherUid: ?otherSeenAt,
      },
    );
  }

  group('computeMessageStatus tests', () {
    test('returns sent for incoming messages from other user', () {
      final msg = createMsg(
        id: 'msg_1',
        senderUid: otherUid,
        createdAt: now,
      );
      final conv = createConv(
        otherDeliveredAt: now.add(const Duration(minutes: 5)),
        otherSeenAt: now.add(const Duration(minutes: 10)),
      );

      final status = computeMessageStatus(
        message: msg,
        conversation: conv,
        myUid: myUid,
        otherUid: otherUid,
      );

      expect(status, MessageStatus.sent);
    });

    test('returns pending for optimistic/temp message IDs', () {
      final msg = createMsg(
        id: 'temp_12345',
        senderUid: myUid,
        createdAt: now,
      );
      final conv = createConv();

      final status = computeMessageStatus(
        message: msg,
        conversation: conv,
        myUid: myUid,
        otherUid: otherUid,
      );

      expect(status, MessageStatus.pending);
    });

    test('returns sent when neither delivered nor seen yet', () {
      final msg = createMsg(
        id: 'msg_1',
        senderUid: myUid,
        createdAt: now,
      );
      final conv = createConv(
        otherDeliveredAt: now.subtract(const Duration(minutes: 5)),
        otherSeenAt: now.subtract(const Duration(minutes: 10)),
      );

      final status = computeMessageStatus(
        message: msg,
        conversation: conv,
        myUid: myUid,
        otherUid: otherUid,
      );

      expect(status, MessageStatus.sent);
    });

    test('returns delivered when message createdAt <= otherUid deliveredAt', () {
      final msg = createMsg(
        id: 'msg_1',
        senderUid: myUid,
        createdAt: now,
      );
      final conv = createConv(
        otherDeliveredAt: now.add(const Duration(seconds: 1)),
        otherSeenAt: null,
      );

      final status = computeMessageStatus(
        message: msg,
        conversation: conv,
        myUid: myUid,
        otherUid: otherUid,
      );

      expect(status, MessageStatus.delivered);
    });

    test('returns read when message createdAt <= otherUid seenAt', () {
      final msg = createMsg(
        id: 'msg_1',
        senderUid: myUid,
        createdAt: now,
      );
      final conv = createConv(
        otherDeliveredAt: now.add(const Duration(seconds: 1)),
        otherSeenAt: now.add(const Duration(seconds: 2)),
      );

      final status = computeMessageStatus(
        message: msg,
        conversation: conv,
        myUid: myUid,
        otherUid: otherUid,
        readReceiptsEnabled: true,
      );

      expect(status, MessageStatus.read);
    });

    test('returns delivered instead of read when read receipts are disabled', () {
      final msg = createMsg(
        id: 'msg_1',
        senderUid: myUid,
        createdAt: now,
      );
      final conv = createConv(
        otherDeliveredAt: now.add(const Duration(seconds: 1)),
        otherSeenAt: now.add(const Duration(seconds: 2)),
      );

      final status = computeMessageStatus(
        message: msg,
        conversation: conv,
        myUid: myUid,
        otherUid: otherUid,
        readReceiptsEnabled: false,
      );

      expect(status, MessageStatus.delivered);
    });

    test('returns sent if conversation is null', () {
      final msg = createMsg(
        id: 'msg_1',
        senderUid: myUid,
        createdAt: now,
      );

      final status = computeMessageStatus(
        message: msg,
        conversation: null,
        myUid: myUid,
        otherUid: otherUid,
      );

      expect(status, MessageStatus.sent);
    });
  });
}
