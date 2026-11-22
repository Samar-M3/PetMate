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
          child: InkWell(
            onTap: onMyAppointmentsTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CareTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.calendar_month, color: CareTheme.terracotta),
                  const SizedBox(height: 8),
                  const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
                  const SizedBox(height: 4),
                  Text('$upcomingCount Upcoming', style: const TextStyle(fontSize: 12, color: CareTheme.mutedText)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onHealthRecordsTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CareTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_information, color: CareTheme.deepOlive),
                  const SizedBox(height: 8),
                  const Text('Health Records', style: TextStyle(fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
                  const SizedBox(height: 4),
                  Text('Vaccine: $nextVaccineDate', style: const TextStyle(fontSize: 12, color: CareTheme.mutedText)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
