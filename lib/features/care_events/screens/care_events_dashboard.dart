// Combines your top header (PetMate / Care & Events),
// BookVetHeroCard, QuickCareCards, and a scrollable list of EventListCard widgets on a Warm Beige (#E9E6D8) background.
import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../models/mock_care_data.dart';
import '../widgets/book_vet_hero_card.dart';
import '../widgets/event_list_card.dart';
import '../widgets/quick_care_cards.dart';
import 'appointments/health_records_screen.dart';
import 'appointments/my_appointments_screen.dart';
import 'appointments/vet_list_screen.dart';
import 'events/event_detail_screen.dart';
import 'events/events_calendar_screen.dart';
import 'vet_management/vet_admin_dashboard.dart';

class CareEventsDashboard extends StatefulWidget {
  const CareEventsDashboard({super.key});

  @override
  State<CareEventsDashboard> createState() => _CareEventsDashboardState();
}

class _CareEventsDashboardState extends State<CareEventsDashboard> {
  @override
  Widget build(BuildContext context) {
    final upcomingCount = MockCareData.appointments
        .where((a) => a.status == 'Upcoming')
        .length;

    return Scaffold(
      backgroundColor: CareTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CareTheme.deepOlive,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.pets_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PetMate',
                              style: TextStyle(
                                  fontSize: 12, color: CareTheme.mutedText)),
                          Text('Care & Events',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: CareTheme.charcoal)),
                        ],
                      ),
                    ],
                  ),
                  // Button to open Veterinarian Management Portal
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: CareTheme.cardBg,
                      foregroundColor: CareTheme.charcoal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.medical_information_outlined,
                        size: 18, color: CareTheme.deepOlive),
                    label: const Text('Vet Portal',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VetAdminDashboard()),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Book a Vet Hero Card
              BookVetHeroCard(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VetListScreen()),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 22),

              // Care Section
              const Text(
                'Care for Toto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: CareTheme.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              QuickCareCards(
                upcomingCount: upcomingCount,
                nextVaccineDate: 'Dec 28',
                onMyAppointmentsTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyAppointmentsScreen()),
                  );
                  setState(() {});
                },
                onHealthRecordsTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HealthRecordsScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Local Pet Events Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Local Pet Events',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: CareTheme.charcoal,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EventsCalendarScreen()),
                      );
                      setState(() {});
                    },
                    child: const Text(
                      'See calendar >',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CareTheme.terracotta,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...MockCareData.events.map(
                    (event) => EventListCard(
                  event: event,
                  onBookmarkTap: () =>
                      setState(() => event.isBookmarked = !event.isBookmarked),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: event)),
                    );
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
