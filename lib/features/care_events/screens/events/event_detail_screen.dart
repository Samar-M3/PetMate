import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/event_model.dart';

class EventDetailScreen extends StatefulWidget {
  final PetEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final ev = widget.event;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: Text(ev.title, style: const TextStyle(color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CareTheme.sagePill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ev.category,
                style: const TextStyle(fontWeight: FontWeight.bold, color: CareTheme.deepOlive),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ev.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CareTheme.charcoal),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: CareTheme.terracotta),
                const SizedBox(width: 8),
                Text('${ev.fullDate} (${ev.time})', style: const TextStyle(color: CareTheme.charcoal)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: CareTheme.terracotta),
                const SizedBox(width: 8),
                Expanded(child: Text(ev.location, style: const TextStyle(color: CareTheme.charcoal))),
              ],
            ),
            const SizedBox(height: 20),
            const Text('About Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
            const SizedBox(height: 8),
            Text(ev.description, style: const TextStyle(fontSize: 14, height: 1.5, color: CareTheme.charcoal)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CareTheme.terracotta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    ev.isBooked = !ev.isBooked;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ev.isBooked ? 'Event booked successfully!' : 'Booking cancelled')),
                  );
                },
                child: Text(ev.isBooked ? 'Cancel Booking' : 'Book Pass', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
