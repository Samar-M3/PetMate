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
}
