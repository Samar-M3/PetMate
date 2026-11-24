import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/appointment_model.dart';
import '../../providers/care_events_provider.dart';
import '../../utils/care_format.dart';
import '../../widgets/care_ui.dart';

class HealthRecordsScreen extends ConsumerWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(appointmentsProvider);
    final nextVaccine = ref.watch(nextVaccineDueProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('Pet Health Records'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CareTheme.deepOlive,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.vaccines_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upcoming Vaccination',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          nextVaccine == null
                              ? 'No vaccinations due. Your vet will add dates after a visit.'
                              : 'Next vaccine due ${formatCareDate(nextVaccine)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Past Clinic Notes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: CareTheme.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: apptsAsync.when(
                loading: () => const CareLoading(),
                error: (e, _) => CareErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(appointmentsProvider),
                ),
                data: (list) {
                  final completed = list
                      .where((a) => a.status == Appointment.completed)
                      .toList();
                  if (completed.isEmpty) {
                    return const CareMessage(
                      'No completed clinic records yet.',
                    );
                  }
                  return ListView.builder(
                    itemCount: completed.length,
                    itemBuilder: (context, index) =>
                        _recordCard(completed[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(Appointment rec) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CareTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${rec.petName} • ${rec.reason} (${rec.date})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: CareTheme.charcoal,
            ),
          ),
          Text(
            'Vet: ${rec.vetName}',
            style: const TextStyle(fontSize: 12, color: CareTheme.mutedText),
          ),
          const SizedBox(height: 8),
          Text(
            rec.vetNotes ?? 'No notes added.',
            style: const TextStyle(color: CareTheme.charcoal),
          ),
        ],
      ),
    );
  }
}
