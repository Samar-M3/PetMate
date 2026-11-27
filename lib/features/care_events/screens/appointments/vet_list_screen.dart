import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/vet_model.dart';
import '../../providers/care_events_provider.dart';
import '../../utils/care_format.dart';
import '../../widgets/care_ui.dart';
import 'book_appointment_screen.dart';

class VetListScreen extends ConsumerStatefulWidget {
  const VetListScreen({super.key});

  @override
  ConsumerState<VetListScreen> createState() => _VetListScreenState();
}

class _VetListScreenState extends ConsumerState<VetListScreen> {
  String _searchQuery = '';

  bool _matches(Vet v) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return v.name.toLowerCase().contains(q) ||
        v.specialty.toLowerCase().contains(q) ||
        v.clinicName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final vetsAsync = ref.watch(veterinariansProvider);

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('Book a Vet Clinic'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search doctor, clinic or specialty...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: CareTheme.mutedText,
                ),
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
                loading: () => const CareLoading(),
                error: (err, _) => CareErrorRetry(
                  error: err,
                  onRetry: () => ref.invalidate(veterinariansProvider),
                ),
                data: (vets) {
                  final filtered = vets
                      .where(
                        (v) =>
                            v.isVerified &&
                            v.isAcceptingBookings &&
                            _matches(v),
                      )
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(careVetsProvider.notifier).refresh(),
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 80),
                              CareMessage(
                                'No veterinarians are available right now.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildVetTile(filtered[index]),
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

  Widget _buildVetTile(Vet vet) {
    final hasSlots = vet.availableSlots.isNotEmpty;

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
                child: Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                ),
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
                        fontSize: 13,
                        color: CareTheme.mutedText,
                      ),
                    ),
                    Text(
                      vet.address.isEmpty
                          ? vet.clinicName
                          : '${vet.clinicName} • ${vet.address}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CareTheme.deepOlive,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    vet.rating > 0
                        ? '★ ${vet.rating.toStringAsFixed(1)}'
                        : 'New',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (vet.fee > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatFee(vet.fee),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: CareTheme.terracotta,
                      ),
                    ),
                  ],
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: hasSlots
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookAppointmentScreen(vet: vet),
                      ),
                    )
                  : null,
              child: Text(
                hasSlots ? 'Select Clinic Slot' : 'No slots available',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
