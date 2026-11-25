import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether read receipts are shown, persisted locally for this device.
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
      final value = prefs.getBool(_prefKey);
      if (value != null && value != state) state = value;
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
