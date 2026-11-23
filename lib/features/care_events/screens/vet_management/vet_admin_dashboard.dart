import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../providers/care_events_provider.dart';
import 'manage_schedule_screen.dart';

class VetAdminDashboard extends ConsumerWidget {
  const VetAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vetsAsync = ref.watch(veterinariansProvider);
    final apptsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text('Vet Clinic Portal',
            style: TextStyle(
                color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            vetsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading clinic: $e'),
              data: (vets) {
                if (vets.isEmpty) {
                  return const Text('No clinic profile assigned yet.');
                }
                final vet = vets.first;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CareTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vet.name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CareTheme.charcoal)),
                      Text(vet.clinicName,
                          style: const TextStyle(color: CareTheme.mutedText)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CareTheme.deepOlive,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded),
                          label: const Text('Manage Clinic Time Slots'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageScheduleScreen(vet: vet),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Patient Appointment Queue',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: CareTheme.charcoal)),
            const SizedBox(height: 10),
            Expanded(
              child: apptsAsync.when(
                loading: () => const Center(
                    child:
                    CircularProgressIndicator(color: CareTheme.terracotta)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (bookings) {
                  if (bookings.isEmpty) {
                    return const Center(
                        child: Text('No patient appointments yet.'));
                  }
                  return ListView.builder(
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final appt = bookings[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CareTheme.cardBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Pet: ${appt.petName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(appt.status,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: CareTheme.terracotta)),
                              ],
                            ),
                            Text('${appt.date} • ${appt.timeSlot}'),
                            Text('Reason: ${appt.reason}',
                                style: const TextStyle(
                                    color: CareTheme.mutedText)),
                            if (appt.status == 'Upcoming') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CareTheme.sageGreen,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => ref
                                        .read(appointmentsProvider.notifier)
                                        .updateStatus(
                                      appt.id,
                                      status: 'COMPLETED',
                                      vetNotes:
                                      'In-clinic exam completed. Pet is healthy.',
                                    ),
                                    child: const Text('Mark Completed'),
                                  ),
                                  const SizedBox(width: 10),
                                  TextButton(
                                    onPressed: () => ref
                                        .read(appointmentsProvider.notifier)
                                        .updateStatus(appt.id,
                                        status: 'CANCELLED'),
                                    child: const Text('Decline',
                                        style: TextStyle(
                                            color: CareTheme.terracotta)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
