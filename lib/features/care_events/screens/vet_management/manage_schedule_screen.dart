import 'package:flutter/material.dart';

import '../../models/app_theme.dart';
import '../../models/vet_model.dart';

class ManageScheduleScreen extends StatefulWidget {
  final Vet vet;

  const ManageScheduleScreen({super.key, required this.vet});

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen> {
  final List<String> _allPossibleSlots = [
    '09:30 AM',
    '11:00 AM',
    '01:00 PM',
    '02:30 PM',
    '04:45 PM',
    '06:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text(
          'Clinic Time Slots',
          style: TextStyle(
            color: CareTheme.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toggle Active In-Clinic Slots',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CareTheme.charcoal,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allPossibleSlots.map((slot) {
                final active = widget.vet.availableSlots.contains(slot);
                return FilterChip(
                  label: Text(slot),
                  selected: active,
                  selectedColor: CareTheme.sageGreen,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        widget.vet.availableSlots.add(slot);
                      } else {
                        widget.vet.availableSlots.remove(slot);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
