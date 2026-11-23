import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  final FirebaseDatabase _db;
  final String _uid;
  final bool _visible;
  late final String _connectionId;

  StreamSubscription<DatabaseEvent>? _connectedSub;
  StreamSubscription<DatabaseEvent>? _offsetSub;
  int _serverTimeOffsetMs = 0;
  bool _isDisposed = false;
  bool _isConnected = false;

  PresenceService(
    this._uid, {
    FirebaseDatabase? db,
    this._visible = true,
  })  : _db = db ?? FirebaseDatabase.instance {
    _connectionId = '${DateTime.now().millisecondsSinceEpoch}_${_uid.hashCode}';
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  int get serverTimeOffsetMs => _serverTimeOffsetMs;

  DateTime get serverNow =>
      DateTime.now().add(Duration(milliseconds: _serverTimeOffsetMs));

  void _init() {
    // 1. Listen to server time offset
    _offsetSub = _db.ref('.info/serverTimeOffset').onValue.listen((event) {
      final offset = event.snapshot.value;
      if (offset is num) {
        _serverTimeOffsetMs = offset.toInt();
      }
    });

    // 2. Listen to connection state
    _connectedSub = _db.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value == true;
      _isConnected = connected;
      if (connected && !_isDisposed) {
        _goOnline();
      }
    });
  }

  Future<void> _goOnline() async {
    if (_uid.isEmpty || _isDisposed) return;
    try {
      final statusRef = _db.ref('status/$_uid');
      final connRef = statusRef.child('connections/$_connectionId');

      // Setup onDisconnect hooks first
      await connRef.onDisconnect().remove();
      await statusRef.child('lastOnline').onDisconnect().set(ServerValue.timestamp);

      // Now set current active connection
      await connRef.set(true);
      await statusRef.child('visible').set(_visible);
    } catch (_) {
      // Ignored if network dropped
    }
  }

  Future<void> _goOffline() async {
    if (_uid.isEmpty || _isDisposed) return;
    try {
      final statusRef = _db.ref('status/$_uid');
      final connRef = statusRef.child('connections/$_connectionId');
      await connRef.remove();
      await statusRef.child('lastOnline').set(ServerValue.timestamp);
    } catch (_) {
      // Ignored
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.resumed) {
      if (_isConnected) {
        _goOnline();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _goOffline();
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _offsetSub?.cancel();
    await _connectedSub?.cancel();
    await _goOffline();
  }
}
