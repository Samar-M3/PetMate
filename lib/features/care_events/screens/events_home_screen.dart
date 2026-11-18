import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../models/mock_care_data.dart';
import '../widgets/event_list_card.dart';
import 'events/event_detail_screen.dart';
import 'events/my_event_bookings_screen.dart';

class EventsHomeScreen extends StatefulWidget {
  const EventsHomeScreen({super.key});

  @override
  State<EventsHomeScreen> createState() => _EventsHomeScreenState();
}

class _EventsHomeScreenState extends State<EventsHomeScreen> {
  String _selectedCategory = 'ALL';
  final List<String> _categories = ['ALL', 'MEETUP', 'AGILITY', 'WORKSHOP'];

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _selectedCategory == 'ALL'
        ? MockCareData.events
        : MockCareData.events
        .where((e) => e.category == _selectedCategory)
        .toList();

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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyEventBookingsScreen()),
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

          // Events List
          Expanded(
            child: filteredEvents.isEmpty
                ? const Center(
              child: Text(
                'No events in this category yet.',
                style: TextStyle(color: CareTheme.mutedText),
              ),
            )
                : ListView.builder(
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final ev = filteredEvents[index];
                return EventListCard(
                  event: ev,
                  onBookmarkTap: () =>
                      setState(() => ev.isBookmarked = !ev.isBookmarked),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: ev)),
                    );
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
