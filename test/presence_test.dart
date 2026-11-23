import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/features/chat/domain/entities/presence_model.dart';

void main() {
  group('relativeActivityText Boundary Tests', () {
    final now = DateTime(2026, 11, 23, 12, 0, 0);

    test('isOnline true returns "Active now"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(hours: 2)), true);
      expect(text, 'Active now');
    });

    test('offline 59s ago returns "Active now"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(seconds: 59)), false);
      expect(text, 'Active now');
    });

    test('offline 1m ago returns "Active 1m ago"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(seconds: 60)), false);
      expect(text, 'Active 1m ago');
    });

    test('offline 59m ago returns "Active 59m ago"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(minutes: 59)), false);
      expect(text, 'Active 59m ago');
    });

    test('offline 1h ago returns "Active 1h ago"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(hours: 1)), false);
      expect(text, 'Active 1h ago');
    });

    test('offline 23h ago returns "Active 23h ago"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(hours: 23)), false);
      expect(text, 'Active 23h ago');
    });

    test('offline 1d ago returns "Active 1d ago"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(days: 1)), false);
      expect(text, 'Active 1d ago');
    });

    test('offline 6d ago returns "Active 6d ago"', () {
      final text = relativeActivityText(now, now.subtract(const Duration(days: 6)), false);
      expect(text, 'Active 6d ago');
    });

    test('offline 7d ago returns null (boundary)', () {
      final text = relativeActivityText(now, now.subtract(const Duration(days: 7)), false);
      expect(text, isNull);
    });

    test('offline > 7d ago returns null', () {
      final text = relativeActivityText(now, now.subtract(const Duration(days: 14)), false);
      expect(text, isNull);
    });

    test('visible false returns null regardless of status', () {
      final text = relativeActivityText(now, now, true, visible: false);
      expect(text, isNull);
    });

    test('Nepali locale localization produces Nepali text', () {
      expect(
        relativeActivityText(now, now, true, locale: 'ne'),
        'अहिले सक्रिय',
      );
      expect(
        relativeActivityText(now, now.subtract(const Duration(minutes: 5)), false, locale: 'ne'),
        '5 मि अघि सक्रिय',
      );
      expect(
        relativeActivityText(now, now.subtract(const Duration(hours: 3)), false, locale: 'ne'),
        '3 घ अघि सक्रिय',
      );
      expect(
        relativeActivityText(now, now.subtract(const Duration(days: 2)), false, locale: 'ne'),
        '2 दिन अघि सक्रिय',
      );
    });
  });

  group('UserPresence Model Tests', () {
    test('parses active connections as isOnline true', () {
      final map = {
        'connections': {'conn_1': true},
        'lastOnline': 1763884800000,
        'visible': true,
      };
      final presence = UserPresence.fromMap(map);
      expect(presence.isOnline, isTrue);
      expect(presence.visible, isTrue);
      expect(presence.lastOnline?.millisecondsSinceEpoch, 1763884800000);
    });

    test('parses empty connections as isOnline false', () {
      final map = {
        'connections': <String, dynamic>{},
        'lastOnline': 1763884800000,
        'visible': true,
      };
      final presence = UserPresence.fromMap(map);
      expect(presence.isOnline, isFalse);
    });

    test('parses visible false correctly', () {
      final map = {
        'visible': false,
      };
      final presence = UserPresence.fromMap(map);
      expect(presence.visible, isFalse);
    });
  });
}
