import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presence_provider.dart';

/// Pure function to test whether a typing timestamp from the server is fresh (< 6000 ms).
bool isTypingTimestampFresh(
  num? timestampMs,
  num serverNowMs, {
  num maxAgeMs = 6000,
}) {
  if (timestampMs == null) return false;
  final age = serverNowMs - timestampMs;
  return age >= -1000 && age <= maxAgeMs; // allow minor future clock drift up to 1s
}

/// Provider that listens to `typing/{conversationId}/{otherUid}` in Realtime Database.
/// Enforces:
/// 1. Only treats as typing if timestamp is newer than 6 seconds.
/// 2. Automatically expires to false after 6 seconds if no new updates occur.
/// 3. Reciprocity: returns false if the user turned off activity status.
final otherUserTypingProvider = StreamProvider.autoDispose
    .family<bool, ({String conversationId, String otherUid})>((ref, arg) {
  final canShow = ref.watch(showActivityStatusProvider);
  if (!canShow || arg.conversationId.isEmpty || arg.otherUid.isEmpty) {
    return Stream.value(false);
  }

  final rtdb = FirebaseDatabase.instance;
  final typingRef = rtdb.ref('typing/${arg.conversationId}/${arg.otherUid}');

  final controller = StreamController<bool>();
  Timer? expiryTimer;

  final sub = typingRef.onValue.listen((event) {
    expiryTimer?.cancel();
    final val = event.snapshot.value;

    if (val is num) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isFresh = isTypingTimestampFresh(val, nowMs);

      if (isFresh) {
        controller.add(true);
        final elapsedMs = (nowMs - val).clamp(0, 6000);
        final remainingMs = 6000 - elapsedMs;

        expiryTimer = Timer(Duration(milliseconds: remainingMs.toInt()), () {
          if (!controller.isClosed) {
            controller.add(false);
          }
        });
      } else {
        controller.add(false);
      }
    } else {
      controller.add(false);
    }
  });

  ref.onDispose(() {
    expiryTimer?.cancel();
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
