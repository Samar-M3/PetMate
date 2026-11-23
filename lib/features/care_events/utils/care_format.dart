const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// Parses "Dec 05, 2026" or an ISO-8601 string into a calendar date
/// (time of day and time zone are dropped so the day never shifts).
DateTime? parseCareDate(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return null;

  final match = RegExp(r'^([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{1,2}),?\s+(\d{4})$')
      .firstMatch(s);
  if (match != null) {
    final month = _months.indexWhere(
        (m) => m.toLowerCase() == match.group(1)!.toLowerCase());
    if (month != -1) {
      return DateTime(
          int.parse(match.group(3)!), month + 1, int.parse(match.group(2)!));
    }
  }

  final iso = DateTime.tryParse(s);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  return null;
}

/// "Dec 05, 2026"
String formatCareDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';

/// Normalises any supported date string for display; returns the input if unparseable.
String displayCareDate(String raw) {
  final d = parseCareDate(raw);
  return d == null ? raw : formatCareDate(d);
}

/// "SUN"
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

/// "Nov" style short month.
String monthShort(DateTime d) => _months[d.month - 1];

DateTime todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Minutes after midnight for "09:30 AM" / "2:30 pm"; null if unparseable.
int? slotMinutes(String slot) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(slot.trim());
  if (m == null) return null;
  var h = int.parse(m.group(1)!) % 12;
  if (m.group(3)!.toLowerCase() == 'pm') h += 12;
  return h * 60 + int.parse(m.group(2)!);
}

List<String> sortedSlots(Iterable<String> slots) {
  final list = slots.toSet().toList();
  list.sort((a, b) =>
      (slotMinutes(a) ?? 1 << 30).compareTo(slotMinutes(b) ?? 1 << 30));
  return list;
}

String formatFee(int fee) => '₹$fee';
