// The two side-by-side cards under "Care for Toto"
// (Video consult with the green online indicator dot, and Health records with the upcoming vaccine date).
import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class QuickCareCards extends StatelessWidget {
  final int upcomingCount;
  final String nextVaccineDate;
  final VoidCallback onMyAppointmentsTap;
  final VoidCallback onHealthRecordsTap;

  const QuickCareCards({
    super.key,
    required this.upcomingCount,
    required this.nextVaccineDate,
    required this.onMyAppointmentsTap,
    required this.onHealthRecordsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            icon: Icons.calendar_month_rounded,
            iconColor: CareTheme.terracotta,
            title: 'My bookings',
            subtitle: '$upcomingCount clinic visit${upcomingCount == 1 ? '' : 's'}',
            dotColor: CareTheme.sageGreen,
            onTap: onMyAppointmentsTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            icon: Icons.verified_user_rounded,
            iconColor: CareTheme.deepOlive,
            title: 'Health records',
            subtitle: 'Due: $nextVaccineDate',
            onTap: onHealthRecordsTap,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? dotColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CareTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CareTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: CareTheme.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CareTheme.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
