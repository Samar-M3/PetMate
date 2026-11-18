import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';

class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final completed = MockCareData.appointments
        .where((a) => a.status == 'Completed')
        .toList();

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text('Toto\'s Health Records',
            style: TextStyle(
                color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CareTheme.deepOlive,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.vaccines_rounded, color: Colors.white, size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upcoming Vaccination',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('Annual DHPP Booster due Dec 28, 2026',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Past Clinic Notes',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: CareTheme.charcoal)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: completed.length,
                itemBuilder: (context, index) {
                  final rec = completed[index];
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
                        Text('${rec.reason} (${rec.date})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: CareTheme.charcoal)),
                        Text('Vet: ${rec.vetName}',
                            style: const TextStyle(
                                fontSize: 12, color: CareTheme.mutedText)),
                        const SizedBox(height: 8),
                        Text(rec.vetNotes ?? 'No notes added.',
                            style: const TextStyle(color: CareTheme.charcoal)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
