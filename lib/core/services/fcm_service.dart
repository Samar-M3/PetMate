import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../router/app_router.dart';
import 'notification_repository.dart';
import 'storage_service.dart';

// -----------------------------------------------------------------------------
// Active Conversation Provider (to suppress foreground chat notifications)
// -----------------------------------------------------------------------------

final activeConversationProvider =
    NotifierProvider<ActiveConversationNotifier, String?>(
      ActiveConversationNotifier.new,
    );

class ActiveConversationNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String? conversationId) {
    state = conversationId;
  }
}

// -----------------------------------------------------------------------------
// Pending Deep Link Provider (for deferred navigation post-login)
// -----------------------------------------------------------------------------

final pendingNotificationRouteProvider =
    NotifierProvider<PendingRouteNotifier, String?>(PendingRouteNotifier.new);

class PendingRouteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRoute(String? route) => state = route;
  void clear() => state = null;
}

// -----------------------------------------------------------------------------
// Top-Level Background Message Handler
// -----------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Never log tokens or sensitive message contents!
  if (kDebugMode) {
    debugPrint(
      '[FCM Background] Message received (id: ${message.messageId}, type: ${message.data['type']})',
    );
  }
}

// -----------------------------------------------------------------------------
// FCM Service Provider
// -----------------------------------------------------------------------------

final fcmServiceProvider = Provider<FcmService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = FcmService(ref, repo, prefs);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

class FcmService {
  final Ref _ref;
  final NotificationRepository _repo;
  final SharedPreferences _prefs;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _prefKeyLastToken = 'fcm_last_registered_token';
  static const String _prefKeyPermissionPrompted = 'fcm_permission_prompted';
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _initializeFuture;
  Future<void>? _syncTokenFuture;
  bool _disposed = false;

  FcmService(this._ref, this._repo, this._prefs);

  /// Initializes local notifications, channels, and FCM listeners.
  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    if (kIsWeb || _disposed) return; // Skip unsupported or disposed services.
    // 1. Android notification initialization
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final route = data['route'] as String?;
            if (route != null) {
              handleNotificationTap(route);
            }
          } catch (_) {}
        }
      },
    );

    // 2. Create notification channels on Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'messages',
          'Chat Messages',
          description: 'Notifications for incoming chat messages',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'requests_matches',
          'Matches & Requests',
          description: 'Notifications for pet match requests and new matches',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'orders',
          'Orders & Shop',
          description: 'Notifications for shop orders and deliveries',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'system',
          'System Announcements',
          description: 'General system announcements and account updates',
          importance: Importance.defaultImportance,
        ),
      );
    }

    // 3. Foreground message listener
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      }),
    );

    // 4. Background-to-foreground tap handler
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final route = message.data['route'] as String?;
        if (route != null) {
          handleNotificationTap(route);
        }
      }),
    );

    // 5. Token refresh listener
    // ignore: deprecated_member_use
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        syncToken(force: true);
      }),
    );

    // 6. Check for cold start initial message
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final route = initialMessage.data['route'] as String?;
      if (route != null) {
        _ref.read(pendingNotificationRouteProvider.notifier).setRoute(route);
      }
    }
  }

  /// Handles foreground notifications. Suppresses chat messages if viewing that chat.
  void _handleForegroundMessage(RemoteMessage message) {
    final category = message.data['category'] as String?;
    final conversationId = message.data['conversationId'] as String?;
    final activeConv = _ref.read(activeConversationProvider);

    // Suppress notification if currently in the conversation
    if (category == 'messages' &&
        conversationId != null &&
        activeConv != null &&
        conversationId == activeConv) {
      if (kDebugMode) {
        debugPrint(
          '[FCM Foreground] Suppressed push for active chat: $conversationId',
        );
      }
      return;
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'PetMate';
    final body = notification?.body ?? message.data['body'] ?? '';

    final channelId = _resolveChannelId(category);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      importance: (channelId == 'messages' || channelId == 'requests_matches')
          ? Importance.high
          : Importance.defaultImportance,
      priority: (channelId == 'messages' || channelId == 'requests_matches')
          ? Priority.high
          : Priority.defaultPriority,
      color: AppColors.primary,
      icon: '@mipmap/ic_launcher',
      tag: message.data['collapseKey'] as String?,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    // ID is derived from notification tag or timestamp
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  String _resolveChannelId(String? category) {
    switch (category) {
      case 'messages':
        return 'messages';
      case 'requests':
      case 'matches':
        return 'requests_matches';
      case 'orders':
        return 'orders';
      case 'system':
      default:
        return 'system';
    }
  }

  String _channelName(String channelId) {
    switch (channelId) {
      case 'messages':
        return 'Chat Messages';
      case 'requests_matches':
        return 'Matches & Requests';
      case 'orders':
        return 'Orders & Shop';
      case 'system':
      default:
        return 'System Announcements';
    }
  }

  /// Synchronizes the FCM device token with the backend.
  Future<void> syncToken({bool force = false}) =>
      _syncTokenFuture ??= _syncToken(force).whenComplete(() {
        _syncTokenFuture = null;
      });

  Future<void> _syncToken(bool force) async {
    if (kIsWeb || _disposed) return; // Skip unsupported or disposed services.
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final lastToken = _prefs.getString(_prefKeyLastToken);
      if (!force && lastToken == token) {
        return;
      }

      await _repo.registerDeviceToken(
        token: token,
        platform: 'android',
        locale: 'en',
      );

      await _prefs.setString(_prefKeyLastToken, token);
      if (kDebugMode) {
        debugPrint('[FCM] Device token registered with backend successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to sync device token: $e');
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Removes the device token from the backend and deletes it locally on logout.
  Future<void> deleteTokenOnLogout() async {
    try {
      final lastToken = _prefs.getString(_prefKeyLastToken);
      if (lastToken != null && lastToken.isNotEmpty) {
        try {
          await _repo.deleteDeviceToken(lastToken);
        } catch (_) {}
      }
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
      await _prefs.remove(_prefKeyLastToken);
      if (kDebugMode) {
        debugPrint('[FCM] Local and remote device tokens deleted on logout.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error during token removal on logout: $e');
      }
    }
  }

  /// Prompts for notification permission with an explanation dialog.
  /// Triggered after the first match or when the first chat opens (never at launch).
  Future<void> checkAndPromptPermission(BuildContext context) async {
    if (kIsWeb) return;
    final alreadyPrompted = _prefs.getBool(_prefKeyPermissionPrompted) ?? false;
    if (alreadyPrompted) return;

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _prefs.setBool(_prefKeyPermissionPrompted, true);
      await syncToken();
      return;
    }

    if (!context.mounted) return;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Stay Connected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Enable push notifications to get alerted about new pet matches, messages from owners, and updates about your pets.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Not Now',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable Notifications'),
          ),
        ],
      ),
    );

    await _prefs.setBool(_prefKeyPermissionPrompted, true);

    if (shouldRequest == true) {
      final updatedSettings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (updatedSettings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        await syncToken();
      } else if (context.mounted) {
        showPermissionDeniedBanner(context);
      }
    }
  }

  /// Shows a banner when permission is denied that links to system notification settings.
  void showPermissionDeniedBanner(BuildContext context) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFFFF4E5),
        leading: const Icon(
          Icons.notifications_off_rounded,
          color: AppColors.terracotta,
        ),
        content: const Text(
          'Notifications are off. You might miss new messages and pet matches.',
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text(
              'Dismiss',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps payload route to GoRouter navigation.
  void handleNotificationTap(String rawRoute) {
    try {
      final router = _ref.read(appRouterProvider);
      router.go(rawRoute);
    } catch (e) {
      _ref.read(pendingNotificationRouteProvider.notifier).setRoute(rawRoute);
    }
  }
}
