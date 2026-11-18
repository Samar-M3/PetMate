import 'package:flutter/material.dart';

import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';
import 'manage_schedule_screen.dart';
import 'vet_profile_form_screen.dart';

class VetAdminDashboard extends StatefulWidget {
  const VetAdminDashboard({super.key});

  @override
  State<VetAdminDashboard> createState() => _VetAdminDashboardState();
}

class _VetAdminDashboardState extends State<VetAdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final vet = MockCareData.vets.first;
    final bookings = MockCareData.appointments;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text(
          'Vet Clinic Portal',
          style: TextStyle(
            color: CareTheme.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add New Vet',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VetProfileFormScreen()),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clinic Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CareTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vet.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CareTheme.charcoal,
                    ),
                  ),
                  Text(
                    vet.clinicName,
                    style: const TextStyle(color: CareTheme.mutedText),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CareTheme.deepOlive,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('Manage Clinic Time Slots'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageScheduleScreen(vet: vet),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Patient Appointment Queue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: CareTheme.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final appt = bookings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CareTheme.cardBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pet: ${appt.petName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              appt.status,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: CareTheme.terracotta,
                              ),
                            ),
                          ],
                        ),
                        Text('${appt.date} • ${appt.timeSlot}'),
                        Text(
                          'Reason: ${appt.reason}',
                          style: const TextStyle(color: CareTheme.mutedText),
                        ),
                        if (appt.status == 'Upcoming') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CareTheme.sageGreen,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    appt.status = 'Completed';
                                    appt.vetNotes = 'In-clinic exam completed. Pet is healthy.';
                                  });
                                },
                                child: const Text('Mark Completed'),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: () =>
                                    setState(() => appt.status = 'Cancelled'),
                                child: const Text(
                                  'Decline',
                                  style: TextStyle(color: CareTheme.terracotta),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
