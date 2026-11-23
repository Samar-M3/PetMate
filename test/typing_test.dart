import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/features/chat/presentation/providers/typing_provider.dart';

void main() {
  group('Typing Expiry & Freshness Logic', () {
    const nowMs = 1763884800000;

    test('timestamp within 6 seconds is fresh', () {
      expect(isTypingTimestampFresh(nowMs - 1000, nowMs), isTrue); // 1s old
      expect(isTypingTimestampFresh(nowMs - 3000, nowMs), isTrue); // 3s old
      expect(isTypingTimestampFresh(nowMs - 5999, nowMs), isTrue); // 5.999s old
      expect(isTypingTimestampFresh(nowMs, nowMs), isTrue);        // 0s old
    });

    test('timestamp at exactly 6000ms is fresh (boundary)', () {
      expect(isTypingTimestampFresh(nowMs - 6000, nowMs), isTrue);
    });

    test('timestamp older than 6 seconds is expired', () {
      expect(isTypingTimestampFresh(nowMs - 6001, nowMs), isFalse);
      expect(isTypingTimestampFresh(nowMs - 10000, nowMs), isFalse);
      expect(isTypingTimestampFresh(nowMs - 60000, nowMs), isFalse);
    });

    test('null timestamp returns false', () {
      expect(isTypingTimestampFresh(null, nowMs), isFalse);
    });

    test('future timestamps within 1s tolerance allowed, far future rejected', () {
      expect(isTypingTimestampFresh(nowMs + 500, nowMs), isTrue);  // 500ms future drift allowed
      expect(isTypingTimestampFresh(nowMs + 2000, nowMs), isFalse); // > 1s future drift rejected
    });
  });
}
