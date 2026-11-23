import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../models/event_model.dart';
import '../../providers/care_events_provider.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final PetEvent event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late bool _isBooked;
  late int _attendeeCount;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isBooked = widget.event.isBooked;
    _attendeeCount = widget.event.attendeeCount;
  }

  Future<void> _toggleBooking() async {
    setState(() => _loading = true);
    final nextBooked = !_isBooked;
    try {
      await ref
          .read(careEventsProvider.notifier)
          .toggleRsvp(widget.event.id, nextBooked);
      setState(() {
        _isBooked = nextBooked;
        _attendeeCount += nextBooked ? 1 : -1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update RSVP: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text('Event Details',
            style: TextStyle(
                color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CareTheme.sageGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.category,
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(e.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('${e.fullDate} • ${e.time}',
                      style: const TextStyle(color: Colors.white)),
                  Text(e.location,
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('About this Event',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: CareTheme.charcoal)),
            const SizedBox(height: 8),
            Text(e.description,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: CareTheme.charcoal)),
            const SizedBox(height: 16),
            Text('+$_attendeeCount pet parents going',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: CareTheme.deepOlive)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _isBooked ? CareTheme.deepOlive : CareTheme.terracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _loading ? null : _toggleBooking,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  _isBooked
                      ? 'Spot Booked (Tap to Cancel)'
                      : 'Book Event Spot',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
