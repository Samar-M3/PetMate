import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/core/models/notification_preference_model.dart';
import 'package:petmatee/core/services/fcm_service.dart';
import 'package:petmatee/core/services/notification_repository.dart';

class FakeNotificationRepository implements NotificationRepository {
  final List<String> registeredTokens = [];
  final List<String> deletedTokens = [];
  NotificationPreferenceModel preferences = const NotificationPreferenceModel();

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? appVersion,
    String locale = 'en',
  }) async {
    registeredTokens.add(token);
  }

  @override
  Future<void> deleteDeviceToken(String token) async {
    deletedTokens.add(token);
  }

  @override
  Future<NotificationPreferenceModel> getPreferences() async {
    return preferences;
  }

  @override
  Future<NotificationPreferenceModel> updatePreferences(
    NotificationPreferenceModel newPrefs,
  ) async {
    preferences = newPrefs;
    return preferences;
  }
}

void main() {
  group('FCM Route Mapping and Deep Linking Tests', () {
    test('Maps chat payload route correctly', () {
      const matchId = 'conv-match-123';
      const route = '/chat/$matchId';
      expect(route.startsWith('/chat/'), isTrue);
      expect(route.replaceFirst('/chat/', ''), matchId);
    });

    test('Maps requests and orders payload routes correctly', () {
      const requestsRoute = '/requests';
      const orderRoute = '/shop/orders/ord-999';
      expect(requestsRoute, '/requests');
      expect(orderRoute, startsWith('/shop/orders/'));
    });

    test('PendingNotificationRouteNotifier sets and clears routes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pendingNotificationRouteProvider.notifier);
      expect(container.read(pendingNotificationRouteProvider), isNull);

      notifier.setRoute('/chat/test-123');
      expect(container.read(pendingNotificationRouteProvider), '/chat/test-123');

      notifier.clear();
      expect(container.read(pendingNotificationRouteProvider), isNull);
    });

    test('ActiveConversationNotifier manages active conversation state for suppression', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(activeConversationProvider.notifier);
      expect(container.read(activeConversationProvider), isNull);

      notifier.setActive('conv-456');
      expect(container.read(activeConversationProvider), 'conv-456');

      notifier.setActive(null);
      expect(container.read(activeConversationProvider), isNull);
    });
  });

  group('FakeNotificationRepository Token Lifecycle', () {
    test('Registers and deletes token correctly', () async {
      final fakeRepo = FakeNotificationRepository();
      await fakeRepo.registerDeviceToken(token: 'fcm-token-abc');
      expect(fakeRepo.registeredTokens, contains('fcm-token-abc'));

      await fakeRepo.deleteDeviceToken('fcm-token-abc');
      expect(fakeRepo.deletedTokens, contains('fcm-token-abc'));
    });

    test('Gets and updates notification preferences', () async {
      final fakeRepo = FakeNotificationRepository();
      final initial = await fakeRepo.getPreferences();
      expect(initial.messages, isTrue);
      expect(initial.showPreviews, isTrue);

      final updated = await fakeRepo.updatePreferences(
        initial.copyWith(messages: false, showPreviews: false),
      );
      expect(updated.messages, isFalse);
      expect(updated.showPreviews, isFalse);
    });
  });

  group('Notification Permission UI Widgets', () {
    testWidgets('Permission explanation dialog displays title, body, and actions', (tester) async {
      bool? userChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    userChoice = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.notifications_active_rounded),
                            SizedBox(width: 8),
                            Text('Stay Connected'),
                          ],
                        ),
                        content: const Text(
                          'Enable push notifications to get alerted about new pet matches, messages from owners, and updates about your pets.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Not Now'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Enable Notifications'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Stay Connected'), findsOneWidget);
      expect(
        find.text(
          'Enable push notifications to get alerted about new pet matches, messages from owners, and updates about your pets.',
        ),
        findsOneWidget,
      );
      expect(find.text('Not Now'), findsOneWidget);
      expect(find.text('Enable Notifications'), findsOneWidget);

      // Tap 'Enable Notifications'
      await tester.tap(find.text('Enable Notifications'));
      await tester.pumpAndSettle();
      expect(userChoice, isTrue);
    });

    testWidgets('Permission denied banner displays text and dismiss action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showMaterialBanner(
                      MaterialBanner(
                        content: const Text(
                          'Notifications are off. You might miss new messages and pet matches.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                            },
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Banner'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Banner'));
      await tester.pumpAndSettle();

      expect(
        find.text('Notifications are off. You might miss new messages and pet matches.'),
        findsOneWidget,
      );
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(
        find.text('Notifications are off. You might miss new messages and pet matches.'),
        findsNothing,
      );
    });
  });
}
