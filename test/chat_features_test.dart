import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/core/constants/chat_constants.dart';
import 'package:petmatee/core/services/api_client.dart';
import 'package:petmatee/features/chat/data/repositories/chat_repository.dart';
import 'package:petmatee/features/chat/domain/entities/chat_entities.dart';
import 'package:petmatee/features/chat/presentation/widgets/date_separator.dart';

class MockApiClient extends Fake implements ApiClient {}

void main() {
  group('Date and Timestamp Formatting', () {
    test('formatDateSeparator returns Today for current date', () {
      final now = DateTime.now();
      expect(formatDateSeparator(now), 'Today');
    });

    test('formatDateSeparator returns Yesterday for 1 day ago', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(formatDateSeparator(yesterday), 'Yesterday');
    });

    test('formatDateSeparator returns weekday for 3 days ago', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final separator = formatDateSeparator(threeDaysAgo);
      expect(separator, isNotEmpty);
      expect(separator, isNot('Today'));
      expect(separator, isNot('Yesterday'));
    });

    test('formatDateSeparator returns full date for > 7 days ago', () {
      final oldDate = DateTime(2026, 11, 12, 14, 30);
      final separator = formatDateSeparator(oldDate);
      expect(separator.contains('2026'), isTrue);
      expect(separator.contains('Nov'), isTrue);
    });

    test('formatChatListTimestamp formats correctly', () {
      final now = DateTime.now();
      final todayFormatted = formatChatListTimestamp(now);
      expect(todayFormatted.contains('AM') || todayFormatted.contains('PM'), isTrue);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(formatChatListTimestamp(yesterday), 'Yesterday');
    });

    test('isDifferentDay detects same vs different days', () {
      final date1 = DateTime(2026, 11, 22, 10, 0);
      final date2 = DateTime(2026, 11, 22, 18, 30);
      final date3 = DateTime(2026, 11, 23, 10, 0);

      expect(isDifferentDay(date1, date2), isFalse);
      expect(isDifferentDay(date1, date3), isTrue);
    });
  });

  group('Domain Entities Serialization', () {
    test('ReplyToData serialization and deserialization', () {
      final reply = ReplyToData(
        messageId: 'msg-1',
        senderUid: 'user-1',
        type: 'text',
        preview: 'Hello reply',
      );

      final map = reply.toMap();
      expect(map['messageId'], 'msg-1');
      expect(map['preview'], 'Hello reply');

      final fromMap = ReplyToData.fromMap(map);
      expect(fromMap.messageId, 'msg-1');
      expect(fromMap.preview, 'Hello reply');
    });

    test('MediaItem serialization and deserialization', () {
      final item = MediaItem(
        kind: 'image',
        publicId: 'chat/match-1/img-1',
        format: 'jpg',
        bytes: 102400,
        width: 800,
        height: 600,
      );

      expect(item.isImage, isTrue);
      expect(item.isVideo, isFalse);

      final map = item.toMap();
      expect(map['kind'], 'image');
      expect(map['bytes'], 102400);

      final fromMap = MediaItem.fromMap(map);
      expect(fromMap.publicId, 'chat/match-1/img-1');
      expect(fromMap.width, 800);
    });

    test('MediaItem video properties', () {
      final item = MediaItem(
        kind: 'video',
        publicId: 'chat/match-1/vid-1',
        format: 'mp4',
        bytes: 2048000,
        width: 1280,
        height: 720,
        durationSeconds: 15.5,
        thumbnailPublicId: 'chat/match-1/thumb-1',
      );

      expect(item.isVideo, isTrue);
      expect(item.isImage, isFalse);
      expect(item.durationSeconds, 15.5);
    });

    test('FirestoreMessage deletion checks', () {
      final msg = FirestoreMessage(
        id: 'msg-1',
        senderUid: 'user-1',
        text: 'Test',
        createdAt: DateTime.now(),
        deletedFor: ['user-1'],
        deletedForEveryone: false,
      );

      expect(msg.isDeletedFor('user-1'), isTrue);
      expect(msg.isDeletedFor('user-2'), isFalse);
      expect(msg.isVisiblyDeleted('user-1'), isTrue);
      expect(msg.isVisiblyDeleted('user-2'), isFalse);
    });
  });

  group('ChatRepository Reply & Delete-for-me', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ChatRepository chatRepository;
    const matchId = 'match-xyz';
    const myUid = 'user-a';
    const otherUid = 'user-b';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      chatRepository = ChatRepository(MockApiClient(), fakeFirestore);
    });

    test('sendMessage with replyTo stores type text and replyTo snapshot', () async {
      await fakeFirestore.collection('conversations').doc(matchId).set({
        'matchId': matchId,
        'participantUids': [myUid, otherUid],
        'status': 'ACTIVE',
        'unread': {myUid: 0, otherUid: 0},
      });

      final reply = ReplyToData(
        messageId: 'orig-1',
        senderUid: otherUid,
        type: 'text',
        preview: 'Original text',
      );

      await chatRepository.sendMessage(
        matchId,
        'Replying back!',
        myUid,
        otherUid,
        replyTo: reply,
      );

      final messagesSnap = await fakeFirestore
          .collection('conversations')
          .doc(matchId)
          .collection('messages')
          .get();

      expect(messagesSnap.docs.length, 1);
      final msg = messagesSnap.docs.first.data();
      expect(msg['type'], 'text');
      expect(msg['replyTo'], isNotNull);
      expect(msg['replyTo']['messageId'], 'orig-1');
      expect(msg['replyTo']['preview'], 'Original text');
    });

    test('deleteForMe adds myUid to deletedFor array', () async {
      final msgRef = fakeFirestore
          .collection('conversations')
          .doc(matchId)
          .collection('messages')
          .doc('msg-to-delete');

      await msgRef.set({
        'senderUid': otherUid,
        'text': 'A message',
        'type': 'text',
        'deletedFor': [],
      });

      await chatRepository.deleteForMe(matchId, 'msg-to-delete', myUid);

      final snap = await msgRef.get();
      final data = snap.data()!;
      expect(data['deletedFor'], contains(myUid));
    });
  });

  group('ChatConstants Verification', () {
    test('constants match product limits', () {
      expect(ChatConstants.maxImageMb, 10);
      expect(ChatConstants.maxVideoMb, 25);
      expect(ChatConstants.maxVideoSeconds, 60);
      expect(ChatConstants.maxMediaPerMessage, 10);
      expect(ChatConstants.imageTargetMb, 1);
      expect(ChatConstants.videoTargetMb, 10);
      expect(ChatConstants.deleteForEveryoneWindowMinutes, 2880);
      expect(ChatConstants.mediaUploadsPerHour, 60);
      expect(ChatConstants.mediaRetentionDays, 90);
    });
  });
}
