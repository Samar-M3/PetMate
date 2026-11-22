class PetEvent {
  final String id;
  final String title;
  final String category;
  final String dayName;
  final String dayNum;
  final String fullDate;
  final String time;
  final String location;
  final String description;
  final int attendeeCount;
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
