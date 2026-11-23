import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/appointment_model.dart';
import '../../providers/care_events_provider.dart';
import '../../utils/care_format.dart';
import '../../widgets/care_ui.dart';
import 'manage_schedule_screen.dart';

class VetAdminDashboard extends ConsumerWidget {
  const VetAdminDashboard({super.key});

  Future<void> _complete(
      BuildContext context, WidgetRef ref, Appointment appt) async {
    final result = await showDialog<_VisitSummary>(
      context: context,
      builder: (_) => _CompleteVisitDialog(petName: appt.petName),
    );
    if (result == null || !context.mounted) return;

    try {
      await ref.read(appointmentsProvider.notifier).updateStatus(
            appt.id,
            status: 'COMPLETED',
            vetNotes: result.notes,
            nextVaccineDue: result.nextVaccineDue,
          );
      if (context.mounted) showCareSnackBar(context, 'Visit marked completed.');
    } catch (e) {
      if (context.mounted) {
        showCareSnackBar(context, 'Could not update: $e', isError: true);
      }
    }
  }

  Future<void> _decline(
      BuildContext context, WidgetRef ref, Appointment appt) async {
    final ok = await confirmCareAction(
      context,
      title: 'Decline appointment?',
      message: '${appt.petName} on ${appt.date} at ${appt.timeSlot} will be cancelled.',
      confirmLabel: 'Decline',
      cancelLabel: 'Keep it',
    );
    if (!ok || !context.mounted) return;

    try {
      await ref
          .read(appointmentsProvider.notifier)
          .updateStatus(appt.id, status: 'CANCELLED');
    } catch (e) {
      if (context.mounted) {
        showCareSnackBar(context, 'Could not update: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myVetProfileProvider);
    final apptsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('Vet Clinic Portal'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            profileAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load your clinic: $e'),
              data: (vet) {
                if (vet == null) {
                  return const Text(
                      'No clinic profile is linked to this account yet.');
                }
                return Container(
                  width: double.infinity,
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
                loading: () => const CareLoading(),
                error: (e, _) => CareErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(appointmentsProvider),
                ),
                data: (bookings) => RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref.read(appointmentsProvider.notifier).refresh();
                    } catch (e) {
                      if (context.mounted) {
                        showCareSnackBar(context, 'Could not refresh: $e',
                            isError: true);
                      }
                    }
                  },
                  child: bookings.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 60),
                            CareMessage('No patient appointments yet.'),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) =>
                              _card(context, ref, bookings[index]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Appointment appt) {
    return Container(
      width: double.infinity,
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
              Expanded(
                child: Text('Pet: ${appt.petName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Text(appt.status,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: CareTheme.terracotta)),
            ],
          ),
          Text('${appt.date} • ${appt.timeSlot}'),
          Text('Reason: ${appt.reason}',
              style: const TextStyle(color: CareTheme.mutedText)),
          if (appt.isUpcoming) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CareTheme.sageGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _complete(context, ref, appt),
                  child: const Text('Mark Completed'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => _decline(context, ref, appt),
                  child: const Text('Decline',
                      style: TextStyle(color: CareTheme.terracotta)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitSummary {
  final String? notes;
  final String? nextVaccineDue;
  const _VisitSummary({this.notes, this.nextVaccineDue});
}

/// Lets the vet record real clinical notes (and an optional next vaccine date)
/// instead of saving a canned message.
class _CompleteVisitDialog extends StatefulWidget {
  final String petName;
  const _CompleteVisitDialog({required this.petName});

  @override
  State<_CompleteVisitDialog> createState() => _CompleteVisitDialogState();
}

class _CompleteVisitDialogState extends State<_CompleteVisitDialog> {
  final _notes = TextEditingController();
  DateTime? _nextVaccine;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = todayDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextVaccine ?? today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) setState(() => _nextVaccine = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Complete visit: ${widget.petName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _notes,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Clinic notes',
                hintText: 'Findings, treatment, advice...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.vaccines_rounded, size: 18),
              label: Text(_nextVaccine == null
                  ? 'Set next vaccine date (optional)'
                  : 'Next vaccine: ${formatCareDate(_nextVaccine!)}'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CareTheme.deepOlive,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final notes = _notes.text.trim();
            Navigator.pop(
              context,
              _VisitSummary(
                notes: notes.isEmpty ? null : notes,
                nextVaccineDue:
                    _nextVaccine == null ? null : formatCareDate(_nextVaccine!),
              ),
            );
          },
          child: const Text('Mark Completed'),
        ),
      ],
    );
  }
}
