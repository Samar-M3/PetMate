import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category;
  final String type;
  final String? route;
  final Map<String, String> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.type,
    this.route,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? type,
    String? route,
    Map<String, String>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      type: type ?? this.type,
      route: route ?? this.route,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'type': type,
    'route': route,
    'data': data,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final parsedData = <String, String>{};
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        if (entry.value != null) {
          parsedData[entry.key.toString()] = entry.value.toString();
        }
      }
    }

    DateTime parsedDate = DateTime.now();
    final rawDate = json['createdAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    }

    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'PetMate',
      body: json['body']?.toString() ?? '',
      category: json['category']?.toString() ?? 'system',
      type: json['type']?.toString() ?? 'general',
      route: json['route']?.toString(),
      data: parsedData,
      isRead: json['isRead'] == true,
      createdAt: parsedDate,
    );
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawData = map['data'];
    final parsedData = <String, String>{};
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        if (entry.value != null) {
          parsedData[entry.key.toString()] = entry.value.toString();
        }
      }
    }

    DateTime createdAt = DateTime.now();
    final ts = map['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else if (ts is String) {
      createdAt = DateTime.tryParse(ts) ?? DateTime.now();
    }

    return AppNotification(
      id: (map['id'] as String?)?.isNotEmpty == true
          ? map['id'] as String
          : doc.id,
      title: map['title'] as String? ?? 'PetMate',
      body: map['body'] as String? ?? '',
      category: map['category'] as String? ?? 'system',
      type: map['type'] as String? ?? 'general',
      route: map['route'] as String? ?? parsedData['route'],
      data: parsedData,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromRemoteMessage(
    RemoteMessage message, {
    bool isRead = false,
  }) {
    final dataMap = <String, String>{};
    for (final entry in message.data.entries) {
      if (entry.value != null) {
        dataMap[entry.key] = entry.value.toString();
      }
    }

    final notifId =
        dataMap['notificationId'] ??
        message.messageId ??
        'fcm_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

    final title =
        message.notification?.title ?? dataMap['title'] ?? 'PetMate';
    final body = message.notification?.body ?? dataMap['body'] ?? '';

    return AppNotification(
      id: notifId,
      title: title,
      body: body,
      category: dataMap['category'] ?? 'system',
      type: dataMap['type'] ?? 'general',
      route: dataMap['route'],
      data: dataMap,
      isRead: isRead,
      createdAt: message.sentTime ?? DateTime.now(),
    );
  }
}
