import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_model.dart';
import '../providers/care_events_provider.dart';
import '../screens/events/event_detail_screen.dart';
import 'care_ui.dart';
import 'event_list_card.dart';

/// Scrollable, pull-to-refresh list of event cards. Handles bookmark taps
/// (with error feedback) and navigation to the detail screen.
class EventFeed extends ConsumerWidget {
  final List<PetEvent> events;
  final String emptyMessage;
  final EdgeInsetsGeometry padding;

  const EventFeed({
    super.key,
    required this.events,
    required this.emptyMessage,
    this.padding = const EdgeInsets.all(16),
  });

  Future<void> _toggleBookmark(
      BuildContext context, WidgetRef ref, PetEvent ev) async {
    try {
      await ref
          .read(careEventsProvider.notifier)
          .toggleBookmark(ev.id, !ev.isBookmarked);
    } catch (e) {
      if (context.mounted) {
        showCareSnackBar(context, 'Could not update bookmark: $e',
            isError: true);
      }
    }
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(careEventsProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        showCareSnackBar(context, 'Could not refresh: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => _refresh(context, ref),
      child: events.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                CareMessage(emptyMessage),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: events.length,
              itemBuilder: (context, index) {
                final ev = events[index];
                return EventListCard(
                  key: ValueKey(ev.id),
                  event: ev,
                  onBookmarkTap: () => _toggleBookmark(context, ref, ev),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(eventId: ev.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
