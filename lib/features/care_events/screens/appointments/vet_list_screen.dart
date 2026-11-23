import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../models/vet_model.dart';
import '../../providers/care_events_provider.dart';
import 'book_appointment_screen.dart';

class VetListScreen extends ConsumerStatefulWidget {
  const VetListScreen({super.key});

  @override
  ConsumerState<VetListScreen> createState() => _VetListScreenState();
}

class _VetListScreenState extends ConsumerState<VetListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final vetsAsync = ref.watch(veterinariansProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text(
          'Book a Vet Clinic',
          style:
          TextStyle(color: CareTheme.charcoal, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search doctor or specialty...',
                prefixIcon:
                const Icon(Icons.search, color: CareTheme.mutedText),
                filled: true,
                fillColor: CareTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: vetsAsync.when(
                loading: () => const Center(
                    child:
                    CircularProgressIndicator(color: CareTheme.terracotta)),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (vets) {
                  final filteredVets = vets.where((v) {
                    return v.isAcceptingBookings &&
                        (v.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                            v.specialty
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()));
                  }).toList();

                  if (filteredVets.isEmpty) {
                    return const Center(
                      child: Text(
                        'No verified veterinarians added by admin yet.',
                        style: TextStyle(color: CareTheme.mutedText),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredVets.length,
                    itemBuilder: (context, index) =>
                        _buildVetTile(filteredVets[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVetTile(Vet vet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CareTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: CareTheme.sageGreen,
                child:
                Icon(Icons.medical_services_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vet.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CareTheme.charcoal,
                      ),
                    ),
                    Text(
                      vet.specialty,
                      style: const TextStyle(
                          fontSize: 13, color: CareTheme.mutedText),
                    ),
                    Text(
                      '${vet.clinicName} • ${vet.address}',
                      style: const TextStyle(
                          fontSize: 12, color: CareTheme.deepOlive),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('★ ${vet.rating}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${vet.fee}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: CareTheme.terracotta,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CareTheme.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BookAppointmentScreen(vet: vet)),
                );
              },
              child: const Text('Select Clinic Slot'),
            ),
          ),
        ],
      ),
    );
  }
}
