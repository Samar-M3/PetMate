import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../models/event_model.dart';
import '../../providers/care_events_provider.dart';
import '../../widgets/care_ui.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  /// Pass either the id, or an event (only its id is used; live data comes from the provider).
  EventDetailScreen({super.key, String? eventId, PetEvent? event})
    : assert(eventId != null || event != null),
      eventId = eventId ?? event!.id;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  Future<void> _toggleBooking(PetEvent event) async {
    final book = !event.isBooked;
    if (!book) {
      final ok = await confirmCareAction(
        context,
        title: 'Cancel your spot?',
        message: 'Your pass for "${event.title}" will be released.',
        confirmLabel: 'Cancel spot',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(careEventsProvider.notifier).toggleRsvp(event.id, book);
      if (mounted) {
        showCareSnackBar(
          context,
          book ? 'Spot booked. See it in My Passes.' : 'Spot cancelled.',
        );
      }
    } catch (e) {
      if (mounted) {
        showCareSnackBar(
          context,
          'Could not update your booking: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBookmark(PetEvent event) async {
    try {
      await ref
          .read(careEventsProvider.notifier)
          .toggleBookmark(event.id, !event.isBookmarked);
    } catch (e) {
      if (mounted) {
        showCareSnackBar(
          context,
          'Could not update bookmark: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always read the live copy so booking/bookmark changes show instantly.
    final eventsAsync = ref.watch(careEventsProvider);

    if (eventsAsync.isLoading && eventsAsync.value == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: careAppBar('Event Details'),
        body: const CareLoading(),
      );
    }
    if (eventsAsync.hasError && eventsAsync.value == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: careAppBar('Event Details'),
        body: CareErrorRetry(
          error: eventsAsync.error ?? 'Could not load the event.',
          onRetry: () => ref.invalidate(careEventsProvider),
        ),
      );
    }

    PetEvent? found;
    for (final e in eventsAsync.value ?? const <PetEvent>[]) {
      if (e.id == widget.eventId) {
        found = e;
        break;
      }
    }

    if (found == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: careAppBar('Event Details'),
        body: const CareMessage('This event is no longer available.'),
      );
    }
    final event = found;
    final ended = event.isPast && !event.isBooked;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // Hero Event Image App Bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.cream,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  child: IconButton(
                    tooltip: event.isBookmarked
                        ? 'Remove bookmark'
                        : 'Bookmark event',
                    onPressed: () => _toggleBookmark(event),
                    icon: Icon(
                      event.isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 20,
                      color: event.isBookmarked
                          ? AppColors.terracotta
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Hero(
                      tag: 'event-image-${event.id}',
                      child: AppNetworkImage(
                        imageUrl: event.imageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.pets_rounded,
                        transformationWidth: 1080,
                      ),
                    )
                  else
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      child: const Center(
                        child: Icon(
                          Icons.pets_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  // Subtle bottom scrim for clean transition
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.28),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Event Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & Status Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      if (event.isBooked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Spot Booked',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Structured Schedule & Venue Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      children: [
                        _DetailInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date & Time',
                          value: '${event.fullDate} • ${event.time}',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        _DetailInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: event.location,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        _DetailInfoRow(
                          icon: Icons.people_outline_rounded,
                          label: 'Attendees',
                          value: '+${event.attendeeCount} pet parents going',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description Section
                  const Text(
                    'About this Event',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description.trim().isNotEmpty
                        ? event.description
                        : 'No additional details provided for this event.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: event.isBooked
                    ? AppColors.primaryDark
                    : AppColors.terracotta,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_busy || ended) ? null : () => _toggleBooking(event),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      ended
                          ? 'Event has ended'
                          : event.isBooked
                          ? 'Spot Booked (Tap to Cancel)'
                          : 'Book Event Spot',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
