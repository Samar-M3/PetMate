import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/core/models/notification_preference_model.dart';
import 'package:petmatee/core/services/notification_repository.dart';
import 'package:petmatee/features/profile/presentation/pages/notification_settings_page.dart';

class FakeNotificationRepository implements NotificationRepository {
  NotificationPreferenceModel preferences = const NotificationPreferenceModel(
    messages: true,
    requests: true,
    matches: true,
    orders: false,
    system: true,
    showPreviews: true,
  );

  bool shouldFailUpdate = false;
  NotificationPreferenceModel? lastUpdated;

  @override
  Future<NotificationPreferenceModel> getPreferences() async {
    return preferences;
  }

  @override
  Future<NotificationPreferenceModel> updatePreferences(
    NotificationPreferenceModel newPrefs,
  ) async {
    if (shouldFailUpdate) {
      throw Exception('Network error updating preferences');
    }
    preferences = newPrefs;
    lastUpdated = newPrefs;
    return newPrefs;
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? appVersion,
    String locale = 'en',
  }) async {}

  @override
  Future<void> deleteDeviceToken(String token) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeNotificationRepository();
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: const MaterialApp(
        home: NotificationSettingsPage(),
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createSubject());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('renders all preference switches with correct initial values', (tester) async {
    await pumpPage(tester);

    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('ALERT CATEGORIES'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Pet Match Requests'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Orders & Shop'), findsOneWidget);
    expect(find.text('System & Announcements'), findsOneWidget);
    expect(find.text('Show Message Previews'), findsOneWidget);
    expect(find.text('Android System Notification Settings'), findsOneWidget);

    // Verify initial values: orders is false, messages is true
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.length, 6);
    expect(switches[0].value, true); // messages
    expect(switches[1].value, true); // requests
    expect(switches[2].value, true); // matches
    expect(switches[3].value, false); // orders
    expect(switches[4].value, true); // system
    expect(switches[5].value, true); // showPreviews
  });

  testWidgets('toggles preference switch optimistically and updates repository', (tester) async {
    await pumpPage(tester);

    // Toggle Show Message Previews (the last switch)
    final previewSwitchFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SwitchListTile &&
          widget.title is Text &&
          (widget.title as Text).data == 'Show Message Previews',
    );
    expect(previewSwitchFinder, findsOneWidget);

    await tester.tap(previewSwitchFinder);
    await tester.pump();
    await tester.pump();

    // Check optimistic update in UI
    expect(fakeRepo.lastUpdated?.showPreviews, false);

    await tester.pumpAndSettle();
    final updatedSwitch = tester.widget<SwitchListTile>(previewSwitchFinder);
    expect(updatedSwitch.value, false);
  });

  testWidgets('reverts switch value and shows SnackBar when update fails', (tester) async {
    fakeRepo.shouldFailUpdate = true;

    await pumpPage(tester);

    final messagesSwitchFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SwitchListTile &&
          widget.title is Text &&
          (widget.title as Text).data == 'Messages',
    );
    expect(messagesSwitchFinder, findsOneWidget);

    // Initially true
    expect(tester.widget<SwitchListTile>(messagesSwitchFinder).value, true);

    // Tap to toggle off
    await tester.tap(messagesSwitchFinder);
    await tester.pump(); // Optimistic update renders false
    await tester.pump(); // Repository throws, notifier catches and rolls back
    await tester.pumpAndSettle(); // SnackBar animation completes

    // Reverted back to true
    expect(tester.widget<SwitchListTile>(messagesSwitchFinder).value, true);
    // SnackBar appears
    expect(
      find.text('Failed to update notification settings. Reverted.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping system settings button triggers MethodChannel', (tester) async {
    bool channelInvoked = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('petmate/system_settings'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'openNotificationSettings') {
          channelInvoked = true;
          return true;
        }
        return null;
      },
    );

    await pumpPage(tester);

    final systemTile = find.text('Android System Notification Settings');
    expect(systemTile, findsOneWidget);

    await tester.tap(systemTile);
    await tester.pumpAndSettle();

    expect(channelInvoked, true);
  });
}
