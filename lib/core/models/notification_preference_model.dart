class NotificationPreferenceModel {
  final bool messages;
  final bool requests;
  final bool matches;
  final bool orders;
  final bool system;
  final bool showPreviews;

  const NotificationPreferenceModel({
    this.messages = true,
    this.requests = true,
    this.matches = true,
    this.orders = true,
    this.system = true,
    this.showPreviews = true,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      messages: json['messages'] as bool? ?? true,
      requests: json['requests'] as bool? ?? true,
      matches: json['matches'] as bool? ?? true,
      orders: json['orders'] as bool? ?? true,
      system: json['system'] as bool? ?? true,
      showPreviews: json['showPreviews'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messages': messages,
      'requests': requests,
      'matches': matches,
      'orders': orders,
      'system': system,
      'showPreviews': showPreviews,
    };
  }

  NotificationPreferenceModel copyWith({
    bool? messages,
    bool? requests,
    bool? matches,
    bool? orders,
    bool? system,
    bool? showPreviews,
  }) {
    return NotificationPreferenceModel(
      messages: messages ?? this.messages,
      requests: requests ?? this.requests,
      matches: matches ?? this.matches,
      orders: orders ?? this.orders,
      system: system ?? this.system,
      showPreviews: showPreviews ?? this.showPreviews,
    );
  }
}
