import '../utils/care_format.dart';

class PetEvent {
  final String id;
  final String title;
  final String category; // e.g. 'MEETUP', 'AGILITY' (admins can add more)
  final String? imageUrl;
  final String dayName; // 'SUN'
  final String dayNum; // '18'
  final String fullDate; // 'Nov 18, 2026'
  final String time;
  final String location;
  final String description;
  final int attendeeCount;
  final bool isBookmarked;
  final bool isBooked;

  const PetEvent({
    required this.id,
    required this.title,
    required this.category,
    this.imageUrl,
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

  factory PetEvent.fromJson(Map<String, dynamic> j) {
    final rawDate = (j['fullDate'] ?? j['eventDate'] ?? j['date'] ?? '')
        .toString();
    final date = parseCareDate(rawDate);
    final rawImage =
        (j['imageUrl'] ?? j['image_url'] ?? j['posterUrl'] ?? j['poster_url'])
            ?.toString()
            .trim();

    return PetEvent(
      id: j['id'].toString(),
      title: (j['title'] ?? '').toString(),
      category: (j['category'] ?? 'OTHER').toString().toUpperCase(),
      imageUrl: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      // Derive from the real date when possible; older rows stored a fixed 'SUN'.
      dayName: date != null
          ? weekdayShort(date)
          : (j['dayName'] ?? '').toString(),
      dayNum: date != null
          ? date.day.toString()
          : (j['dayNum'] ?? '').toString(),
      fullDate: date != null ? formatCareDate(date) : rawDate,
      time: (j['time'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      attendeeCount: (j['attendeeCount'] as num?)?.toInt() ?? 0,
      isBookmarked: j['isBookmarked'] == true,
      isBooked: (j['isBooked'] ?? j['isRsvped']) == true,
    );
  }

  PetEvent copyWith({
    String? imageUrl,
    int? attendeeCount,
    bool? isBookmarked,
    bool? isBooked,
  }) {
    return PetEvent(
      id: id,
      title: title,
      category: category,
      imageUrl: imageUrl ?? this.imageUrl,
      dayName: dayName,
      dayNum: dayNum,
      fullDate: fullDate,
      time: time,
      location: location,
      description: description,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isBooked: isBooked ?? this.isBooked,
    );
  }

  DateTime? get date => parseCareDate(fullDate);

  /// True once the event day has passed (the event day itself still counts as upcoming).
  bool get isPast {
    final d = date;
    return d != null && d.isBefore(todayDate());
  }
}
