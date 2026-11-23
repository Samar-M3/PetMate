import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../providers/care_events_provider.dart';
import '../widgets/book_vet_hero_card.dart';
import '../widgets/quick_care_cards.dart';
import 'appointments/health_records_screen.dart';
import 'appointments/my_appointments_screen.dart';
import 'appointments/vet_list_screen.dart';
import 'vet_management/vet_admin_dashboard.dart';

class VetApptsHomeScreen extends ConsumerWidget {
  final String userRole;
  const VetApptsHomeScreen({super.key, this.userRole = 'PET_OWNER'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(appointmentsProvider);
    final upcomingCount = apptsAsync.maybeWhen(
      data: (list) => list.where((a) => a.status == 'Upcoming').length,
      orElse: () => 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              if (userRole == 'VETERINARIAN' || userRole == 'ADMIN')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: CareTheme.cardBg,
                    foregroundColor: CareTheme.charcoal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.medical_information_outlined,
                      size: 18, color: CareTheme.deepOlive),
                  label:
                  const Text('Vet Portal', style: TextStyle(fontSize: 12)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const VetAdminDashboard()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          BookVetHeroCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VetListScreen()),
            ),
          ),
          const SizedBox(height: 22),
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
            onMyAppointmentsTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
            ),
            onHealthRecordsTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthRecordsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
