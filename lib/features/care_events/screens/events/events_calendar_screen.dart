import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/event_list_card.dart';
import 'event_detail_screen.dart';
import 'my_event_bookings_screen.dart';

class EventsCalendarScreen extends ConsumerWidget {
  const EventsCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(careEventsProvider);
    final events = eventsAsync.value ?? [];

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text(
          'All Local Pet Events',
          style: TextStyle(
            color: CareTheme.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyEventBookingsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.confirmation_number_outlined,
              size: 18,
              color: CareTheme.terracotta,
            ),
            label: const Text(
              'My Passes',
              style: TextStyle(
                color: CareTheme.terracotta,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CareTheme.deepOlive,
        onRefresh: () async => ref.read(careEventsProvider.notifier).loadEvents(),
        child: events.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No events scheduled yet.',
                      style: TextStyle(color: CareTheme.mutedText),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final ev = events[index];
                  return EventListCard(
                    event: ev,
                    onBookmarkTap: () => ev.isBookmarked = !ev.isBookmarked,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
