import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/presence_service.dart';
import '../../domain/entities/presence_model.dart';
import 'chat_provider.dart';

/// Setting: Show activity status (defaults to true).
final showActivityStatusProvider =
    NotifierProvider<ShowActivityStatusNotifier, bool>(
  ShowActivityStatusNotifier.new,
);

class ShowActivityStatusNotifier extends Notifier<bool> {
  static const _prefKey = 'chat_show_activity_status';

  @override
  bool build() {
    _loadPersisted();
    return true;
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_prefKey);
      if (val != null && val != state) {
        state = val;
      }
    } catch (_) {}
  }

  Future<void> toggle(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }
}

/// Setting: Read receipts (defaults to true).
final readReceiptsSettingProvider =
    NotifierProvider<ReadReceiptsSettingNotifier, bool>(
  ReadReceiptsSettingNotifier.new,
);

class ReadReceiptsSettingNotifier extends Notifier<bool> {
  static const _prefKey = 'chat_read_receipts';

  @override
  bool build() {
    _loadPersisted();
    return true;
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_prefKey);
      if (val != null && val != state) {
        state = val;
      }
    } catch (_) {}
  }

  Future<void> toggle(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }
}

/// Active Presence Service for the logged in user.
final activePresenceServiceProvider = Provider<PresenceService?>((ref) {
  final currentUid = ref.watch(currentFirebaseUidProvider);
  final isVisible = ref.watch(showActivityStatusProvider);

  if (currentUid.isEmpty) return null;

  final service = PresenceService(currentUid, visible: isVisible);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Streams presence for a given user from Realtime Database.
final presenceStreamProvider =
    StreamProvider.autoDispose.family<UserPresence, String>((ref, uid) {
  if (uid.isEmpty) {
    return Stream.value(const UserPresence(isOnline: false, visible: false));
  }

  final rtdb = FirebaseDatabase.instance;
  final refNode = rtdb.ref('status/$uid');

  return refNode.onValue.map((event) {
    final val = event.snapshot.value;
    if (val is Map) {
      return UserPresence.fromMap(val);
    }
    return const UserPresence(isOnline: false, visible: false);
  });
});

/// Computes the relative activity text, updating every 30 seconds.
/// Enforces reciprocity: if the viewer has disabled showActivityStatus, returns null.
final relativeActivityTextProvider =
    StreamProvider.autoDispose.family<String?, String>((ref, uid) {
  final myVisibility = ref.watch(showActivityStatusProvider);
  if (!myVisibility) {
    return Stream.value(null);
  }

  final presenceAsync = ref.watch(presenceStreamProvider(uid));
  final presence = presenceAsync.value;

  if (presence == null || !presence.visible) {
    return Stream.value(null);
  }

  // Ticker every 30 seconds to recalculate relative elapsed time
  final controller = StreamController<String?>();
  void emitCurrent() {
    final now = DateTime.now();
    final text = relativeActivityText(
      now,
      presence.lastOnline,
      presence.isOnline,
      visible: presence.visible,
    );
    if (!controller.isClosed) {
      controller.add(text);
    }
  }

  emitCurrent();
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => emitCurrent());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
