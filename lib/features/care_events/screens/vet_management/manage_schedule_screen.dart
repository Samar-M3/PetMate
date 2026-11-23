import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../models/vet_model.dart';
import '../../providers/care_events_provider.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  final Vet vet;
  const ManageScheduleScreen({super.key, required this.vet});

  @override
  ConsumerState<ManageScheduleScreen> createState() =>
      _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> {
  late List<String> _slots;
  bool _saving = false;

  final List<String> _allPossibleSlots = [
    '09:30 AM',
    '11:00 AM',
    '01:00 PM',
    '02:30 PM',
    '04:45 PM',
    '06:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _slots = List<String>.from(widget.vet.availableSlots);
  }

  Future<void> _saveSlots() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(veterinariansProvider.notifier)
          .updateSlots(widget.vet.id, _slots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinic time slots updated!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update slots: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text('Clinic Time Slots',
            style: TextStyle(
                color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
      ),
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
                final active = _slots.contains(slot);
                return FilterChip(
                  label: Text(slot),
                  selected: active,
                  selectedColor: CareTheme.sageGreen,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _slots.add(slot);
                      } else {
                        _slots.remove(slot);
                      }
                    });
                  },
                );
              }).toList(),
            ),
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
                    ? const CircularProgressIndicator(color: Colors.white)
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
