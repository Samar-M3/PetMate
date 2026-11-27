import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/core/services/api_client.dart';
import 'package:petmatee/features/chat/data/repositories/chat_repository.dart';

class MockApiClient extends Fake implements ApiClient {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ChatRepository chatRepository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    chatRepository = ChatRepository(MockApiClient(), fakeFirestore);
  });

  group('ChatRepository Firestore Operations', () {
    const matchId = 'test-match-123';
    const myUid = 'user-uid-1';
    const otherUid = 'user-uid-2';

    test('sendMessage creates message and updates conversation doc in batch',
        () async {
      // 1. Setup existing conversation document
      await fakeFirestore.collection('conversations').doc(matchId).set({
        'matchId': matchId,
        'participantUids': [myUid, otherUid],
        'status': 'ACTIVE',
        'unread': {myUid: 0, otherUid: 0},
      });

      // 2. Send message
      await chatRepository.sendMessage(
        matchId,
        'Hello from test! 🐾',
        myUid,
        otherUid,
      );

      // 3. Verify message in subcollection
      final messagesSnap = await fakeFirestore
          .collection('conversations')
          .doc(matchId)
          .collection('messages')
          .get();

      expect(messagesSnap.docs.length, 1);
      final msg = messagesSnap.docs.first.data();
      expect(msg['senderUid'], myUid);
      expect(msg['text'], 'Hello from test! 🐾');

      // 4. Verify parent conversation lastMessage and unread increment
      final convSnap =
          await fakeFirestore.collection('conversations').doc(matchId).get();
      final convData = convSnap.data()!;
      expect(convData['lastMessage']['text'], 'Hello from test! 🐾');
      expect(convData['lastMessage']['senderUid'], myUid);
      expect(convData['unread'][otherUid], 1);
    });

    test('sendMessage rejects oversized messages (> 1000 characters)', () async {
      final oversizedText = 'A' * 1001;

      expect(
        () => chatRepository.sendMessage(
          matchId,
          oversizedText,
          myUid,
          otherUid,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('markRead resets my unread count to 0', () async {
      // 1. Setup conversation with unread messages for myUid
      await fakeFirestore.collection('conversations').doc(matchId).set({
        'matchId': matchId,
        'participantUids': [myUid, otherUid],
        'status': 'ACTIVE',
        'unread': {myUid: 3, otherUid: 0},
      });

      // 2. Mark read
      await chatRepository.markRead(matchId, myUid);

      // 3. Verify unread is reset to 0
      final convSnap =
          await fakeFirestore.collection('conversations').doc(matchId).get();
      final convData = convSnap.data()!;
      expect(convData['unread'][myUid], 0);
    });
  });
}
