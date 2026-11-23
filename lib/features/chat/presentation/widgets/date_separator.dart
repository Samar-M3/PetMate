import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

/// Formats a date for chat day separators.
/// Today, Yesterday, weekday name within 7 days, full date otherwise.
String formatDateSeparator(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(messageDay).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEEE').format(date); // e.g. "Wednesday"
  return DateFormat('d MMM yyyy').format(date); // e.g. "12 Nov 2026"
}

/// Formats a timestamp for the chat list.
/// Time for today, Yesterday, weekday within 7 days, date otherwise.
String formatChatListTimestamp(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(messageDay).inDays;

  if (diff == 0) return DateFormat('h:mm a').format(date);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEEE').format(date);
  return DateFormat('d MMM').format(date);
}

/// Returns true if two dates are on different calendar days.
bool isDifferentDay(DateTime a, DateTime b) {
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

/// A pill-shaped day separator widget for the chat list.
class DateSeparatorWidget extends StatelessWidget {
  final DateTime date;

  const DateSeparatorWidget({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatDateSeparator(date),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
