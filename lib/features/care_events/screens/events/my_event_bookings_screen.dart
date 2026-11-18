// Holds id, name, clinicName, specialty, rating (e.g., 4.9), fee
// (e.g., 499), isOnline (boolean for the "3 vets online" dot), isVerified ("Trusted
// care"), and availableSlots (list of times).
import 'package:flutter/material.dart';

import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';
import '../../widgets/event_list_card.dart';
import 'event_detail_screen.dart';

class MyEventBookingsScreen extends StatefulWidget {
  const MyEventBookingsScreen({super.key});

  @override
  State<MyEventBookingsScreen> createState() => _MyEventBookingsScreenState();
}

class _MyEventBookingsScreenState extends State<MyEventBookingsScreen> {
  @override
  Widget build(BuildContext context) {
    final bookedEvents = MockCareData.events.where((e) => e.isBooked).toList();
    final savedEvents = MockCareData.events
        .where((e) => e.isBookmarked)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          backgroundColor: CareTheme.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: CareTheme.charcoal),
          title: const Text(
            'My Events',
            style: TextStyle(
              color: CareTheme.charcoal,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: CareTheme.terracotta,
            unselectedLabelColor: CareTheme.mutedText,
            indicatorColor: CareTheme.terracotta,
            tabs: [
              Tab(text: 'Booked Passes'),
              Tab(text: 'Bookmarked'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEventList(
              bookedEvents,
              emptyMessage: 'No event spots booked yet.',
            ),
            _buildEventList(
              savedEvents,
              emptyMessage: 'No bookmarked events yet.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List events, {required String emptyMessage}) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: CareTheme.mutedText, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final ev = events[index];
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
    );
  }
}
