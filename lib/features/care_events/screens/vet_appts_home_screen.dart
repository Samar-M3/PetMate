import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../models/mock_care_data.dart';
import '../widgets/book_vet_hero_card.dart';
import '../widgets/quick_care_cards.dart';
import 'appointments/health_records_screen.dart';
import 'appointments/my_appointments_screen.dart';
import 'appointments/vet_list_screen.dart';
import 'vet_management/vet_admin_dashboard.dart';

class VetApptsHomeScreen extends StatefulWidget {
  final String userRole;

  const VetApptsHomeScreen({super.key, this.userRole = 'PET_PARENT'});

  @override
  State<VetApptsHomeScreen> createState() => _VetApptsHomeScreenState();
}

class _VetApptsHomeScreenState extends State<VetApptsHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final upcomingCount = MockCareData.appointments
        .where((a) => a.status == 'Upcoming')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title + Role-Protected Vet Portal Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Veterinary Care',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CareTheme.charcoal,
                ),
              ),
              if (widget.userRole == 'VET' || widget.userRole == 'ADMIN')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: CareTheme.cardBg,
                    foregroundColor: CareTheme.charcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(
                    Icons.medical_information_outlined,
                    size: 18,
                    color: CareTheme.deepOlive,
                  ),
                  label: const Text(
                    'Vet Portal',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VetAdminDashboard(),
                      ),
                    );
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

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
            'Pet Health & Bookings',
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
                MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
              );
              setState(() {});
            },
            onHealthRecordsTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthRecordsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
