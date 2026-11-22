// Holds id, title (e.g., "Paws in the Park"), category
// ("MEETUP", "AGILITY"), date ("SUN 18"), time, location, description,
// attendeeCount (46), and isBookmarked / isBooked.
class PetEvent {
  final String id;
  final String title;
  final String category; // 'MEETUP', 'AGILITY', 'WORKSHOP'
  final String dayName; // 'SUN'
  final String dayNum; // '18'
  final String fullDate; // 'Nov 18, 2026'
  final String time;
  final String location;
  final String description;
  int attendeeCount;
  bool isBookmarked;
  bool isBooked;

  PetEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.dayName,
    required this.dayNum,
    required this.fullDate,
    required this.time,
    required this.location,
    required this.description,
    required this.attendeeCount,
    this.isBookmarked = false,
    this.isBooked = false,
  });

  factory PetEvent.fromJson(Map<String, dynamic> json) {
    return PetEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'MEETUP',
      dayName: json['dayName'] as String? ?? json['day_name'] as String? ?? 'DAY',
      dayNum: json['dayNum'] as String? ?? json['day_num'] as String? ?? '1',
      fullDate: json['fullDate'] as String? ?? json['full_date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      attendeeCount: (json['attendeeCount'] ?? json['attendee_count']) as int? ?? 0,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      isBooked: json['isBooked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'dayName': dayName,
      'dayNum': dayNum,
      'fullDate': fullDate,
      'time': time,
      'location': location,
      'description': description,
      'attendeeCount': attendeeCount,
    };
  }
}
