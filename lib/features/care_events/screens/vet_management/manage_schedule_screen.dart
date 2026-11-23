import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/vet_model.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/care_ui.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  final Vet vet;
  const ManageScheduleScreen({super.key, required this.vet});

  @override
  ConsumerState<ManageScheduleScreen> createState() =>
      _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> {
  static const List<String> _allPossibleSlots = [
    '09:30 AM',
    '11:00 AM',
    '01:00 PM',
    '02:30 PM',
    '04:45 PM',
    '06:00 PM',
  ];

  late final Set<String> _slots;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _slots = widget.vet.availableSlots.toSet();
  }

  Future<void> _saveSlots() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(veterinariansProvider.notifier)
          .updateSlots(widget.vet.id, _slots.toList());
      if (!mounted) return;
      showCareSnackBar(context, 'Clinic time slots updated!');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showCareSnackBar(context, 'Failed to update slots: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('Clinic Time Slots'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Toggle Active In-Clinic Slots',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CareTheme.charcoal)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allPossibleSlots.map((slot) {
                return FilterChip(
                  label: Text(slot),
                  selected: _slots.contains(slot),
                  selectedColor: CareTheme.sageGreen,
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _slots.add(slot);
                    } else {
                      _slots.remove(slot);
                    }
                  }),
                );
              }).toList(),
            ),
            if (_slots.isEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'With no slots selected, pet owners cannot book this clinic.',
                style: TextStyle(color: CareTheme.mutedText),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CareTheme.terracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _saveSlots,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Save Clinic Schedule',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
