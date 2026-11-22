import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../care_events/models/vet_model.dart';
import '../../../care_events/providers/care_events_provider.dart';

class AdminVetsTab extends ConsumerWidget {
  const AdminVetsTab({super.key});

  void _showAddVetDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final clinicCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.medical_services_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Register Veterinarian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField(nameCtrl, 'Doctor Name (e.g. Dr. Sita Karki)'),
              const SizedBox(height: 10),
              _inputField(clinicCtrl, 'Clinic Name (e.g. City Vet Care)'),
              const SizedBox(height: 10),
              _inputField(specCtrl, 'Specialty (e.g. Surgery & Orthopedics)'),
              const SizedBox(height: 10),
              _inputField(addressCtrl, 'Location (e.g. Lazimpat, Kathmandu)'),
              const SizedBox(height: 10),
              _inputField(feeCtrl, 'Consultation Fee (₹)', isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || clinicCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(careVetsProvider.notifier).addVet(
                name: nameCtrl.text.trim(),
                clinicName: clinicCtrl.text.trim(),
                specialty: specCtrl.text.trim().isEmpty ? 'General Care' : specCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? 'Kathmandu' : addressCtrl.text.trim(),
                fee: int.tryParse(feeCtrl.text.trim()) ?? 500,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veterinarian registered!'), backgroundColor: AppColors.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Register Vet'),
          ),
        ],
      ),
    );
  }

  static Widget _inputField(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vetsAsync = ref.watch(careVetsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVetDialog(context, ref),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Register Vet', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.read(careVetsProvider.notifier).loadVets(),
            child: vetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (vets) {
                if (vets.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text('No veterinarians listed yet. Tap "+ Register Vet" to add one.')),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: vets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vet = vets[index];
                    return _buildVetCard(context, ref, vet);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVetCard(BuildContext context, WidgetRef ref, Vet vet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            child: const Icon(Icons.medical_services_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vet.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(vet.clinicName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(vet.specialty, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(vet.address, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const Spacer(),
                    Text('Fee: ₹${vet.fee}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            tooltip: 'Remove Vet',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Remove Veterinarian?'),
                  content: Text('Are you sure you want to remove ${vet.name}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(careVetsProvider.notifier).deleteVet(vet.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
