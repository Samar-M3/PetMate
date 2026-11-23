import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/care_ui.dart';
import '../../widgets/event_feed.dart';
import 'my_event_bookings_screen.dart';

/// Full-screen list of every event (including past ones).
class EventsCalendarScreen extends ConsumerWidget {
  const EventsCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(careEventsProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar(
        'All Local Pet Events',
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyEventBookingsScreen()),
            ),
            icon: const Icon(Icons.confirmation_number_outlined,
                size: 18, color: CareTheme.terracotta),
            label: const Text('My Passes',
                style: TextStyle(
                    color: CareTheme.terracotta, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const CareLoading(),
        error: (e, _) => CareErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(careEventsProvider),
        ),
        data: (events) => EventFeed(
          events: events,
          emptyMessage: 'No events published yet.',
        ),
      ),
    );
  }
}
