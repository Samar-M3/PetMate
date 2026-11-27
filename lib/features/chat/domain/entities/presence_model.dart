class UserPresence {
  final bool isOnline;
  final DateTime? lastOnline;
  final bool visible;

  const UserPresence({
    required this.isOnline,
    this.lastOnline,
    this.visible = true,
  });

  factory UserPresence.fromMap(Map<dynamic, dynamic>? data) {
    if (data == null) {
      return const UserPresence(isOnline: false, visible: true);
    }

    final connections = data['connections'];
    final bool hasConnections = connections is Map && connections.isNotEmpty;
    final visible = data['visible'] == true;

    DateTime? lastOnlineDate;
    final lastOnlineRaw = data['lastOnline'];
    if (lastOnlineRaw is num) {
      lastOnlineDate = DateTime.fromMillisecondsSinceEpoch(lastOnlineRaw.toInt());
    }

    return UserPresence(
      isOnline: hasConnections,
      lastOnline: lastOnlineDate,
      visible: visible,
    );
  }
}

/// Formats relative activity text (Instagram-style):
/// - isOnline == true -> "Active now"
/// - offline under 1 minute -> "Active now"
/// - under 60 minutes -> "Active {m}m ago"
/// - under 24 hours -> "Active {h}h ago"
/// - under 7 days -> "Active {d}d ago"
/// - 7 days or more, unknown, or not visible -> null
String? relativeActivityText(
  DateTime now,
  DateTime? lastOnline,
  bool isOnline, {
  bool visible = true,
  String locale = 'en',
}) {
  if (!visible) return null;
  if (isOnline) {
    return locale == 'ne' ? 'अहिले सक्रिय' : 'Active now';
  }
  if (lastOnline == null) return null;

  // Handle minor future drift
  final diff = now.isAfter(lastOnline)
      ? now.difference(lastOnline)
      : Duration.zero;

  final seconds = diff.inSeconds;
  if (seconds < 60) {
    return locale == 'ne' ? 'अहिले सक्रिय' : 'Active now';
  }

  final minutes = diff.inMinutes;
  if (minutes < 60) {
    return locale == 'ne' ? '$minutes मि अघि सक्रिय' : 'Active ${minutes}m ago';
  }

  final hours = diff.inHours;
  if (hours < 24) {
    return locale == 'ne' ? '$hours घ अघि सक्रिय' : 'Active ${hours}h ago';
  }

  final days = diff.inDays;
  if (days < 7) {
    return locale == 'ne' ? '$days दिन अघि सक्रिय' : 'Active ${days}d ago';
  }

  return null;
}
