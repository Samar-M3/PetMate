import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../care_events/providers/care_events_provider.dart';

class AdminVetsTab extends ConsumerWidget {
const AdminVetsTab({super.key});

void _showAddVetDialog(BuildContext context, WidgetRef ref) {
final nameCtrl = TextEditingController();
final emailCtrl = TextEditingController();
final passwordCtrl = TextEditingController();
final clinicCtrl = TextEditingController();
final licenseCtrl = TextEditingController();
final specialtyCtrl = TextEditingController(text: 'General Veterinary Care');
final addressCtrl = TextEditingController();
final feeCtrl = TextEditingController(text: '500');

showDialog(
context: context,
builder: (ctx) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
title: const Row(
children: [
Icon(Icons.medical_services_rounded, color: AppColors.primary),
SizedBox(width: 8),
Text('Add Trusted Veterinarian',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
_inputField(nameCtrl, 'Doctor Name (e.g. Dr. Aarav Sharma) *'),
const SizedBox(height: 10),
_inputField(emailCtrl, 'Clinic Login Email *'),
const SizedBox(height: 10),
_inputField(passwordCtrl, 'Temporary Password (min 6 chars) *'),
const SizedBox(height: 10),
_inputField(clinicCtrl, 'Clinic Name *'),
const SizedBox(height: 10),
_inputField(licenseCtrl, 'Vet Council License No. *'),
const SizedBox(height: 10),
_inputField(specialtyCtrl, 'Specialty'),
const SizedBox(height: 10),
_inputField(addressCtrl, 'Clinic Address (e.g. Jhamsikhel, Lalitpur)'),
const SizedBox(height: 10),
_inputField(feeCtrl, 'Consultation Fee (₹)', isNumber: true),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Cancel'),
),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
),
onPressed: () async {
if (nameCtrl.text.trim().isEmpty ||
emailCtrl.text.trim().isEmpty ||
passwordCtrl.text.trim().length < 6 ||
clinicCtrl.text.trim().isEmpty ||
licenseCtrl.text.trim().isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Please fill all required fields (password min 6 chars).'),
),
);
return;
}

Navigator.pop(ctx);
try {
await ref.read(veterinariansProvider.notifier).addVeterinarian(
name: nameCtrl.text.trim(),
email: emailCtrl.text.trim(),
password: passwordCtrl.text.trim(),
clinicName: clinicCtrl.text.trim(),
licenseNumber: licenseCtrl.text.trim(),
specialty: specialtyCtrl.text.trim(),
address: addressCtrl.text.trim().isEmpty
? 'Lalitpur'
: addressCtrl.text.trim(),
fee: int.tryParse(feeCtrl.text.trim()) ?? 500,
);
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Trusted veterinarian added!'),
backgroundColor: AppColors.success,
),
);
}
} catch (e) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Failed to add veterinarian: $e'),
backgroundColor: AppColors.error,
),
);
}
}
},
child: const Text('Add Doctor'),
),
],
),
);
}

static Widget _inputField(TextEditingController ctrl, String hint,
{bool isNumber = false}) {
return TextField(
controller: ctrl,
keyboardType: isNumber ? TextInputType.number : TextInputType.text,
decoration: InputDecoration(
hintText: hint,
filled: true,
fillColor: AppColors.inputFill,
contentPadding:
const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppColors.border),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppColors.border),
),
),
);
}

@override
Widget build(BuildContext context, WidgetRef ref) {
final vetsAsync = ref.watch(veterinariansProvider);

return Scaffold(
backgroundColor: AppColors.cream,
floatingActionButton: FloatingActionButton.extended(
heroTag: 'admin_add_vet_fab',
onPressed: () => _showAddVetDialog(context, ref),
backgroundColor: AppColors.terracotta,
foregroundColor: Colors.white,
icon: const Icon(Icons.person_add_alt_1_rounded),
label: const Text('Add Veterinarian'),
),
body: vetsAsync.when(
loading: () => const Center(
child: CircularProgressIndicator(color: AppColors.primary),
),
error: (err, _) => Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text('Error loading veterinarians: $err'),
const SizedBox(height: 10),
ElevatedButton(
onPressed: () => ref.invalidate(veterinariansProvider),
child: const Text('Retry'),
),
],
),
),
data: (vets) {
if (vets.isEmpty) {
return const Center(
child: Text(
'No trusted veterinarians added yet.\nTap "+ Add Veterinarian" to register one.',
textAlign: TextAlign.center,
style: TextStyle(color: AppColors.textSecondary),
),
);
}

return RefreshIndicator(
onRefresh: () async => ref.invalidate(veterinariansProvider),
child: ListView.separated(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
itemCount: vets.length,
separatorBuilder: (_, __) => const SizedBox(height: 12),
itemBuilder: (context, index) {
final vet = vets[index];
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppColors.border),
),
child: Row(
children: [
const CircleAvatar(
radius: 24,
backgroundColor: AppColors.primary,
child: Icon(Icons.medical_services_rounded,
color: Colors.white),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(vet.name,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: AppColors.textPrimary)),
Text('${vet.clinicName} • ${vet.specialty}',
style: const TextStyle(
fontSize: 12,
color: AppColors.textSecondary)),
const SizedBox(height: 4),
Text('${vet.address} • Fee: ₹${vet.fee}',
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: AppColors.success)),
],
),
),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10, vertical: 4),
decoration: BoxDecoration(
color: AppColors.success.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(12),
),
child: const Text(
'Verified',
style: TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: AppColors.success,
),
),
),
],
),
);
},
),
);
},
),
);
}
}