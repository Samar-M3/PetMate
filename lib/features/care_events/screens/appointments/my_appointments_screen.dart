import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  @override
  Widget build(BuildContext context) {
    final list = MockCareData.appointments;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text('My Clinic Bookings',
            style: TextStyle(
                color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CareTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.petName} • ${item.vetName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: CareTheme.charcoal)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.status == 'Upcoming'
                            ? CareTheme.sageGreen.withOpacity(0.25)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.status,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CareTheme.deepOlive),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.clinicName,
                    style: const TextStyle(color: CareTheme.mutedText)),
                Text('${item.date} at ${item.timeSlot}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: CareTheme.charcoal)),
                Text('Reason: ${item.reason}',
                    style: const TextStyle(
                        fontSize: 13, color: CareTheme.mutedText)),
                if (item.status == 'Upcoming') ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => item.status = 'Cancelled');
                    },
                    child: const Text('Cancel Appointment',
                        style: TextStyle(color: CareTheme.terracotta)),
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}
