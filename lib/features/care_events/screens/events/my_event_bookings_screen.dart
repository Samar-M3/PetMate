import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../models/event_model.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/event_list_card.dart';
import 'event_detail_screen.dart';

class MyEventBookingsScreen extends ConsumerWidget {
  const MyEventBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(careEventsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          backgroundColor: CareTheme.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: CareTheme.charcoal),
          title: const Text('My Events',
              style: TextStyle(
                  color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
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
        body: eventsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: CareTheme.terracotta)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (events) {
            final booked = events.where((e) => e.isBooked).toList();
            final saved = events.where((e) => e.isBookmarked).toList();
            return TabBarView(
              children: [
                _buildList(context, ref, booked, 'No event spots booked yet.'),
                _buildList(context, ref, saved, 'No bookmarked events yet.'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<PetEvent> list,
      String emptyMsg) {
    if (list.isEmpty) {
      return Center(
          child:
          Text(emptyMsg, style: const TextStyle(color: CareTheme.mutedText)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ev = list[index];
        return EventListCard(
          event: ev,
          onBookmarkTap: () => ref
              .read(careEventsProvider.notifier)
              .toggleBookmark(ev.id, !ev.isBookmarked),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
          ),
        );
      },
    );
  }
}
