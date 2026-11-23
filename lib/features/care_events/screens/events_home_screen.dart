import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../providers/care_events_provider.dart';
import '../widgets/event_list_card.dart';
import 'events/event_detail_screen.dart';
import 'events/my_event_bookings_screen.dart';

class EventsHomeScreen extends ConsumerStatefulWidget {
  const EventsHomeScreen({super.key});

  @override
  ConsumerState<EventsHomeScreen> createState() => _EventsHomeScreenState();
}

class _EventsHomeScreenState extends ConsumerState<EventsHomeScreen> {
  String _selectedCategory = 'ALL';
  final List<String> _categories = ['ALL', 'MEETUP', 'AGILITY', 'OTHER'];

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(careEventsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Local Pet Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CareTheme.charcoal,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: CareTheme.cardBg,
                  foregroundColor: CareTheme.terracotta,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.confirmation_number_outlined, size: 17),
                label: const Text(
                  'My Passes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyEventBookingsScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  selectedColor: CareTheme.deepOlive,
                  backgroundColor: CareTheme.cardBg,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : CareTheme.charcoal,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Live Events Feed
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: CareTheme.terracotta),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load events: $err',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(careEventsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (events) {
                final filteredEvents = _selectedCategory == 'ALL'
                    ? events
                    : events
                    .where((e) => e.category == _selectedCategory)
                    .toList();

                if (filteredEvents.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(careEventsProvider),
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'No events published yet.\nCheck back soon!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: CareTheme.mutedText),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(careEventsProvider),
                  child: ListView.builder(
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final ev = filteredEvents[index];
                      return EventListCard(
                        event: ev,
                        onBookmarkTap: () => ref
                            .read(careEventsProvider.notifier)
                            .toggleBookmark(ev.id, !ev.isBookmarked),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: ev)),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
