import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class TypingService {
  final FirebaseDatabase _db;
  final String conversationId;
  final String myUid;

  Timer? _inactivityTimer;
  DateTime? _lastSentTime;
  bool _isTyping = false;
  bool _isDisposed = false;

  TypingService({
    required this.conversationId,
    required this.myUid,
    FirebaseDatabase? db,
  }) : _db = db ?? FirebaseDatabase.instance;

  bool get isTyping => _isTyping;

  DatabaseReference get _typingRef =>
      _db.ref('typing/$conversationId/$myUid');

  /// Called whenever the text field changes.
  /// Throttles writes to at most once every 3 seconds while typing continues.
  /// Cancels and deletes after 4 seconds of inactivity or when text is empty.
  void onTextChanged(String text, {bool canSendTyping = true}) {
    if (_isDisposed) return;

    if (!canSendTyping || text.trim().isEmpty) {
      stopTyping();
      return;
    }

    final now = DateTime.now();

    if (!_isTyping) {
      _isTyping = true;
      _writeTyping();
      _lastSentTime = now;
    } else if (_lastSentTime != null &&
        now.difference(_lastSentTime!) >= const Duration(seconds: 3)) {
      _writeTyping();
      _lastSentTime = now;
    }

    // Reset 4-second inactivity timer
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 4), () {
      if (!_isDisposed) {
        stopTyping();
      }
    });
  }

  void _writeTyping() {
    try {
      _typingRef.onDisconnect().remove();
      _typingRef.set(ServerValue.timestamp);
    } catch (_) {
      // Ignored
    }
  }

  void stopTyping() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    if (_isTyping) {
      _isTyping = false;
      _lastSentTime = null;
      try {
        _typingRef.remove();
      } catch (_) {
        // Ignored
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    stopTyping();
  }
}
