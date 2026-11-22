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

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(careEventsProvider);
    final allEvents = eventsAsync.value ?? [];

    // Base categories: ALL, MEETUP, AGILITY, OTHER + dynamic categories from events
    final defaultCategories = ['ALL', 'MEETUP', 'AGILITY', 'OTHER'];
    final dynamicCategories = allEvents
        .map((e) => e.category.toUpperCase().trim())
        .where((c) => c.isNotEmpty && !defaultCategories.contains(c))
        .toSet()
        .toList();
    final categories = [...defaultCategories, ...dynamicCategories];

    final filteredEvents = _selectedCategory == 'ALL'
        ? allEvents
        : allEvents.where((e) => e.category.toUpperCase() == _selectedCategory).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title + My Passes Button
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.confirmation_number_outlined, size: 17),
                label: const Text(
                  'My Passes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyEventBookingsScreen(),
                    ),
                  );
                  setState(() {});
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
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
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

          // Events List
          Expanded(
            child: RefreshIndicator(
              color: CareTheme.deepOlive,
              onRefresh: () async =>
                  ref.read(careEventsProvider.notifier).loadEvents(),
              child: filteredEvents.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'No events found in this category.',
                            style: TextStyle(color: CareTheme.mutedText),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final ev = filteredEvents[index];
                        return EventListCard(
                          event: ev,
                          onBookmarkTap: () => setState(
                              () => ev.isBookmarked = !ev.isBookmarked),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: ev),
                              ),
                            );
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
