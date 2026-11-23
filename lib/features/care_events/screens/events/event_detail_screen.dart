import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/event_model.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/care_ui.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  /// Pass either the id, or an event (only its id is used; live data comes from the provider).
  EventDetailScreen({super.key, String? eventId, PetEvent? event})
      : assert(eventId != null || event != null),
        eventId = eventId ?? event!.id;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  Future<void> _toggleBooking(PetEvent event) async {
    final book = !event.isBooked;
    if (!book) {
      final ok = await confirmCareAction(
        context,
        title: 'Cancel your spot?',
        message: 'Your pass for "${event.title}" will be released.',
        confirmLabel: 'Cancel spot',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(careEventsProvider.notifier).toggleRsvp(event.id, book);
      if (mounted) {
        showCareSnackBar(
            context, book ? 'Spot booked! See it in My Passes.' : 'Spot cancelled.');
      }
    } catch (e) {
      if (mounted) {
        showCareSnackBar(context, 'Could not update your booking: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBookmark(PetEvent event) async {
    try {
      await ref
          .read(careEventsProvider.notifier)
          .toggleBookmark(event.id, !event.isBookmarked);
    } catch (e) {
      if (mounted) {
        showCareSnackBar(context, 'Could not update bookmark: $e',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always read the live copy so booking/bookmark changes show instantly.
    final event = ref.watch(careEventsProvider).maybeWhen<PetEvent?>(
          data: (list) {
            for (final e in list) {
              if (e.id == widget.eventId) return e;
            }
            return null;
          },
          orElse: () => null,
        );

    if (event == null) {
      return Scaffold(
        backgroundColor: CareTheme.background,
        appBar: careAppBar('Event Details'),
        body: const CareMessage('This event is no longer available.'),
      );
    }

    final ended = event.isPast && !event.isBooked;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar(
        'Event Details',
        actions: [
          IconButton(
            tooltip: event.isBookmarked ? 'Remove bookmark' : 'Bookmark event',
            onPressed: () => _toggleBookmark(event),
            icon: Icon(
              event.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: event.isBookmarked
                  ? CareTheme.terracotta
                  : CareTheme.charcoal,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                  Text(event.category,
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(event.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('${event.fullDate} • ${event.time}',
                      style: const TextStyle(color: Colors.white)),
                  Text(event.location,
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
            Text(event.description,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: CareTheme.charcoal)),
            const SizedBox(height: 16),
            Text('+${event.attendeeCount} pet parents going',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: CareTheme.deepOlive)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  event.isBooked ? CareTheme.deepOlive : CareTheme.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: (_busy || ended) ? null : () => _toggleBooking(event),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    ended
                        ? 'Event has ended'
                        : event.isBooked
                            ? 'Spot Booked (Tap to Cancel)'
                            : 'Book Event Spot',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
