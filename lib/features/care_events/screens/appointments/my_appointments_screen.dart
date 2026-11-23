import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/appointment_model.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/care_ui.dart';

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, Appointment item) async {
    final ok = await confirmCareAction(
      context,
      title: 'Cancel appointment?',
      message:
          '${item.petName} with ${item.vetName} on ${item.date} at ${item.timeSlot}.',
      confirmLabel: 'Cancel appointment',
    );
    if (!ok || !context.mounted) return;

    try {
      await ref
          .read(appointmentsProvider.notifier)
          .updateStatus(item.id, status: 'CANCELLED');
    } catch (e) {
      if (context.mounted) {
        showCareSnackBar(context, 'Could not cancel: $e', isError: true);
      }
    }
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appointmentsProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        showCareSnackBar(context, 'Could not refresh: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('My Clinic Bookings'),
      body: apptsAsync.when(
        loading: () => const CareLoading(),
        error: (e, _) => CareErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(appointmentsProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    CareMessage('No clinic bookings yet.'),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _buildCard(context, ref, list[index]),
                ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, Appointment item) {
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
              Expanded(
                child: Text('${item.petName} • ${item.vetName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: CareTheme.charcoal)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isUpcoming
                      ? CareTheme.sageGreen.withValues(alpha: 0.25)
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
                  fontWeight: FontWeight.w600, color: CareTheme.charcoal)),
          Text('Reason: ${item.reason}',
              style:
                  const TextStyle(fontSize: 13, color: CareTheme.mutedText)),
          if (item.isUpcoming) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _cancel(context, ref, item),
              child: const Text('Cancel Appointment',
                  style: TextStyle(color: CareTheme.terracotta)),
            ),
          ],
        ],
      ),
    );
  }
}
