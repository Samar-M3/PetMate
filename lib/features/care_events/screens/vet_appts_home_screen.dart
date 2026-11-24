import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_theme.dart';
import '../models/vet_model.dart';
import '../providers/care_events_provider.dart';
import '../utils/care_format.dart';
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
    final upcomingCount = ref
        .watch(appointmentsProvider)
        .maybeWhen(
          data: (list) => list.where((a) => a.isUpcoming).length,
          orElse: () => 0,
        );
    final nextVaccine = ref.watch(nextVaccineDueProvider);

    final listed = ref
        .watch(veterinariansProvider)
        .maybeWhen(
          data: (vets) =>
              vets.where((v) => v.isVerified && v.isAcceptingBookings).toList(),
          orElse: () => const <Vet>[],
        );
    final fees = listed.where((v) => v.fee > 0).map((v) => v.fee);
    final startingFee = fees.isEmpty
        ? null
        : fees.reduce((a, b) => a < b ? a : b);
    final rated = listed.where((v) => v.rating > 0).toList();
    final avgRating = rated.isEmpty
        ? null
        : rated.map((v) => v.rating).reduce((a, b) => a + b) / rated.length;

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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VetAdminDashboard(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          BookVetHeroCard(
            startingFee: startingFee,
            rating: avgRating,
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
            nextVaccineDate: nextVaccine == null
                ? null
                : '${monthShort(nextVaccine)} ${nextVaccine.day}',
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
