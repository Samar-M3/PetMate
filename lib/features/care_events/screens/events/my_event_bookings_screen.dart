import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';

class MyEventBookingsScreen extends StatelessWidget {
  const MyEventBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookedEvents = MockCareData.events.where((e) => e.isBooked).toList();

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: const Text('My Event Passes', style: TextStyle(color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
      ),
      body: bookedEvents.isEmpty
          ? const Center(child: Text('No booked events yet.', style: TextStyle(color: CareTheme.mutedText)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookedEvents.length,
              itemBuilder: (context, index) {
                final ev = bookedEvents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${ev.fullDate} • ${ev.time}\n${ev.location}'),
                  ),
                );
              },
            ),
    );
  }
}
