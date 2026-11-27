import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/care_ui.dart';
import '../../widgets/event_feed.dart';

class MyEventBookingsScreen extends ConsumerWidget {
  const MyEventBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(careEventsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: careAppBar(
          'My Events',
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
          loading: () => const CareLoading(),
          error: (e, _) => CareErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(careEventsProvider),
          ),
          data: (events) => TabBarView(
            children: [
              EventFeed(
                events: events.where((e) => e.isBooked).toList(),
                emptyMessage: 'No event spots booked yet.',
              ),
              EventFeed(
                events: events.where((e) => e.isBookmarked).toList(),
                emptyMessage: 'No bookmarked events yet.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
