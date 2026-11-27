import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_theme.dart';
import '../providers/care_events_provider.dart';
import '../widgets/care_ui.dart';
import '../widgets/event_feed.dart';
import 'events/my_event_bookings_screen.dart';

class EventsHomeScreen extends ConsumerStatefulWidget {
  const EventsHomeScreen({super.key});

  @override
  ConsumerState<EventsHomeScreen> createState() => _EventsHomeScreenState();
}

class _EventsHomeScreenState extends ConsumerState<EventsHomeScreen> {
  static const String _all = 'ALL';
  String _selectedCategory = _all;

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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyEventBookingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: eventsAsync.when(
              loading: () => const CareLoading(),
              error: (err, _) => CareErrorRetry(
                error: err,
                onRetry: () => ref.invalidate(careEventsProvider),
              ),
              data: (events) {
                // Upcoming only; past events stay visible under My Passes.
                final upcoming = events.where((e) => !e.isPast).toList();

                // Categories come from the data, so admin-created ones show up too.
                final categories = [
                  _all,
                  ...{for (final e in upcoming) e.category},
                ];
                final selected = categories.contains(_selectedCategory)
                    ? _selectedCategory
                    : _all;
                final filtered = selected == _all
                    ? upcoming
                    : upcoming.where((e) => e.category == selected).toList();

                return Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = selected == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: CareTheme.deepOlive,
                            backgroundColor: CareTheme.cardBg,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : CareTheme.charcoal,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: EventFeed(
                        events: filtered,
                        padding: EdgeInsets.zero,
                        emptyMessage:
                            'No upcoming events right now.\nCheck back soon!',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
