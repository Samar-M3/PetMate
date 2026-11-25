import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../models/app_notification_model.dart';
import 'storage_service.dart';

const String _pendingBgNotificationsKey = 'fcm_pending_bg_notifications';

/// Persists a background [RemoteMessage] to SharedPreferences so it appears in
/// the in-app notification center as soon as the app resumes or opens.
Future<void> persistBackgroundRemoteMessage(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final item = AppNotification.fromRemoteMessage(message);
    final raw = prefs.getString(_pendingBgNotificationsKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            list.add(entry);
          }
        }
      }
    }
    list.removeWhere((e) => e['id'] == item.id);
    list.insert(0, item.toJson());
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    await prefs.setString(_pendingBgNotificationsKey, jsonEncode(list));
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[InAppNotifications] Failed to persist bg message: $e');
    }
  }
}

class InAppNotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;

  const InAppNotificationsState({
    this.notifications = const [],
    this.isLoading = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  InAppNotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
  }) {
    return InAppNotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final inAppNotificationsProvider =
    NotifierProvider<InAppNotificationsNotifier, InAppNotificationsState>(
      InAppNotificationsNotifier.new,
    );

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(inAppNotificationsProvider).unreadCount;
});

class InAppNotificationsNotifier extends Notifier<InAppNotificationsState> {
  static const int _maxStored = 100;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  String _activeUid = '';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  InAppNotificationsState build() {
    final authState = ref.watch(authStateProvider);
    final uid =
        authState.firebaseUser?.uid ??
        FirebaseAuth.instance.currentUser?.uid ??
        authState.user?.firebaseUid ??
        '';

    ref.onDispose(() {
      _firestoreSub?.cancel();
      _firestoreSub = null;
    });

    if (uid != _activeUid) {
      _activeUid = uid;
      _firestoreSub?.cancel();
      _firestoreSub = null;

      if (uid.isEmpty) {
        return const InAppNotificationsState(notifications: []);
      }

      final cached = _loadFromPrefs(uid);
      Future.microtask(() {
        if (_activeUid == uid) {
          _drainBackgroundPending(uid);
          _subscribeToFirestore(uid);
        }
      });

      return InAppNotificationsState(notifications: cached, isLoading: false);
    }

    return uid.isEmpty
        ? const InAppNotificationsState(notifications: [])
        : state;
  }

  String _prefsKey(String uid) => 'in_app_notifications_$uid';

  List<AppNotification> _loadFromPrefs(String uid) {
    try {
      final raw = _prefs.getString(_prefsKey(uid));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .where((n) => n.id.isNotEmpty)
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveToPrefs(String uid, List<AppNotification> items) async {
    try {
      final trimmed = items.take(_maxStored).toList();
      await _prefs.setString(
        _prefsKey(uid),
        jsonEncode(trimmed.map((n) => n.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _drainBackgroundPending(String uid) async {
    try {
      await _prefs.reload();
      final raw = _prefs.getString(_pendingBgNotificationsKey);
      if (raw == null || raw.isEmpty) return;
      await _prefs.remove(_pendingBgNotificationsKey);

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final bgItems = decoded
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .where((n) => n.id.isNotEmpty)
          .toList();

      for (final item in bgItems) {
        _upsertLocal(uid, item);
        _upsertFirestore(uid, item);
      }
    } catch (_) {}
  }

  void _subscribeToFirestore(String uid) {
    _firestoreSub?.cancel();
    _firestoreSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen(
          (snap) {
            if (_activeUid != uid) return;
            final remoteItems = snap.docs
                .map(AppNotification.fromFirestore)
                .toList();

            // Merge with local items so locally received pushes are preserved
            // even before/if Firestore rules allow client writes.
            final byId = <String, AppNotification>{
              for (final local in state.notifications) local.id: local,
            };

            for (final remote in remoteItems) {
              final existing = byId[remote.id];
              if (existing == null) {
                byId[remote.id] = remote;
              } else {
                // Keep read=true if either local or remote marked it read
                byId[remote.id] = remote.copyWith(
                  isRead: remote.isRead || existing.isRead,
                );
              }
            }

            final merged = byId.values.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            state = state.copyWith(notifications: merged, isLoading: false);
            _saveToPrefs(uid, merged);
          },
          onError: (err) {
            if (kDebugMode) {
              debugPrint('[InAppNotifications] Firestore stream error: $err');
            }
          },
        );
  }

  void _upsertLocal(String uid, AppNotification item) {
    final existingIdx = state.notifications.indexWhere((n) => n.id == item.id);
    final updated = List<AppNotification>.from(state.notifications);
    if (existingIdx >= 0) {
      final existing = updated[existingIdx];
      updated[existingIdx] = item.copyWith(
        isRead: existing.isRead || item.isRead,
      );
    } else {
      updated.insert(0, item);
    }
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(notifications: updated);
    _saveToPrefs(uid, updated);
  }

  Future<void> _upsertFirestore(String uid, AppNotification item) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(item.id);

      final existing = await docRef.get();
      if (existing.exists) {
        if (item.isRead && existing.data()?['isRead'] != true) {
          await docRef.update({'isRead': true});
        }
        return;
      }

      await docRef.set({
        'id': item.id,
        'title': item.title,
        'body': item.body,
        'category': item.category,
        'type': item.type,
        'route': item.route,
        'data': item.data,
        'isRead': item.isRead,
        'createdAt': Timestamp.fromDate(item.createdAt),
      });
    } catch (_) {
      // Non-fatal: local persistence already succeeded.
    }
  }

  Future<void> saveFromRemoteMessage(
    RemoteMessage message, {
    bool isRead = false,
  }) async {
    final uid = _activeUid;
    if (uid.isEmpty) {
      await persistBackgroundRemoteMessage(message);
      return;
    }

    final item = AppNotification.fromRemoteMessage(message, isRead: isRead);
    _upsertLocal(uid, item);
    await _upsertFirestore(uid, item);
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _activeUid;
    if (uid.isEmpty || notificationId.isEmpty) return;

    final updated = state.notifications
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    state = state.copyWith(notifications: updated);
    await _saveToPrefs(uid, updated);

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final uid = _activeUid;
    if (uid.isEmpty) return;

    final unreadIds = state.notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) return;

    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    state = state.copyWith(notifications: updated);
    await _saveToPrefs(uid, updated);

    try {
      final batch = _firestore.batch();
      final col = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications');
      for (final id in unreadIds) {
        batch.update(col.doc(id), {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> syncPendingOnResume() async {
    if (_activeUid.isEmpty) return;
    await _drainBackgroundPending(_activeUid);
  }
}
