import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../providers/care_events_provider.dart';

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(appointmentsProvider);

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
      body: apptsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: CareTheme.terracotta)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No clinic bookings yet.',
                  style: TextStyle(color: CareTheme.mutedText)),
            );
          }

          return ListView.builder(
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
                        onPressed: () => ref
                            .read(appointmentsProvider.notifier)
                            .updateStatus(item.id, status: 'CANCELLED'),
                        child: const Text('Cancel Appointment',
                            style: TextStyle(color: CareTheme.terracotta)),
                      ),
                    ]
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
