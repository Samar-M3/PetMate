import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';

class VetListScreen extends StatelessWidget {
  const VetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vets = MockCareData.vets;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: const Text('Available Veterinarians', style: TextStyle(color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: vets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final vet = vets[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CareTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vet.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
                const SizedBox(height: 4),
                Text('${vet.specialty} • ${vet.clinicName}', style: const TextStyle(fontSize: 13, color: CareTheme.mutedText)),
                const SizedBox(height: 4),
                Text(vet.address, style: const TextStyle(fontSize: 12, color: CareTheme.mutedText)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fee: ₹${vet.fee}', style: const TextStyle(fontWeight: FontWeight.bold, color: CareTheme.terracotta)),
                    Text('★ ${vet.rating}', style: const TextStyle(fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
