import 'package:flutter/material.dart';

import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';
import '../../widgets/event_list_card.dart';
import 'event_detail_screen.dart';
import 'my_event_bookings_screen.dart';

class EventsCalendarScreen extends StatefulWidget {
  const EventsCalendarScreen({super.key});

  @override
  State<EventsCalendarScreen> createState() => _EventsCalendarScreenState();
}

class _EventsCalendarScreenState extends State<EventsCalendarScreen> {
  @override
  Widget build(BuildContext context) {
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyEventBookingsScreen(),
                ),
              );
              setState(() {});
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: MockCareData.events.length,
        itemBuilder: (context, index) {
          final ev = MockCareData.events[index];
          return EventListCard(
            event: ev,
            onBookmarkTap: () =>
                setState(() => ev.isBookmarked = !ev.isBookmarked),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
              );
              setState(() {});
            },
          );
        },
      ),
    );
  }
}
