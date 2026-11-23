import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/models/vet_model.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';
import '../../../../core/constants/app_colors.dart';

class AdminVetsTab extends ConsumerWidget {
  const AdminVetsTab({super.key});

  void _snack(BuildContext context, String msg, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _addVet(BuildContext context, WidgetRef ref) async {
    final form = await showDialog<_VetFormResult>(
      context: context,
      builder: (_) => const _VetFormDialog(),
    );
    if (form == null) return;

    try {
      await ref.read(veterinariansProvider.notifier).addVeterinarian(
        name: form.name,
        email: form.email,
        password: form.password,
        clinicName: form.clinicName,
        licenseNumber: form.licenseNumber,
        specialty: form.specialty,
        address: form.address,
        fee: form.fee,
      );
      _snack(context, 'Trusted veterinarian added!');
    } catch (e) {
      _snack(context, 'Failed to add veterinarian: $e', error: true);
    }
  }

  Future<void> _editVet(BuildContext context, WidgetRef ref, Vet vet) async {
    final form = await showDialog<_VetFormResult>(
      context: context,
      builder: (_) => _VetFormDialog(existing: vet),
    );
    if (form == null) return;

    try {
      await ref.read(veterinariansProvider.notifier).updateVeterinarian(
        vet.id,
        name: form.name,
        clinicName: form.clinicName,
        specialty: form.specialty,
        address: form.address,
        fee: form.fee,
        isAcceptingBookings: form.isAcceptingBookings,
      );
      _snack(context, 'Veterinarian updated!');
    } catch (e) {
      _snack(context, 'Failed to update veterinarian: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vetsAsync = ref.watch(veterinariansProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_add_vet_fab',
        onPressed: () => _addVet(context, ref),
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
            onRefresh: () => ref.read(careVetsProvider.notifier).refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: vets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _vetCard(context, ref, vets[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _vetCard(BuildContext context, WidgetRef ref, Vet vet) {
    final accepting = vet.isAcceptingBookings;
    final badgeColor = accepting ? AppColors.success : AppColors.warning;

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
            child: Icon(Icons.medical_services_rounded, color: Colors.white),
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
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('${vet.address} • Fee: ₹${vet.fee}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  accepting ? 'Verified' : 'Paused',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit veterinarian',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_rounded,
                    size: 20, color: AppColors.primary),
                onPressed: () => _editVet(context, ref, vet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VetFormResult {
  final String name;
  final String email;
  final String password;
  final String clinicName;
  final String licenseNumber;
  final String specialty;
  final String address;
  final int fee;
  final bool isAcceptingBookings;

  const _VetFormResult({
    required this.name,
    this.email = '',
    this.password = '',
    required this.clinicName,
    this.licenseNumber = '',
    required this.specialty,
    required this.address,
    required this.fee,
    required this.isAcceptingBookings,
  });
}

/// Add (existing == null) or edit a veterinarian. Email, password and licence
/// are only asked for when adding; they are not editable afterwards.
class _VetFormDialog extends StatefulWidget {
  final Vet? existing;
  const _VetFormDialog({this.existing});

  @override
  State<_VetFormDialog> createState() => _VetFormDialogState();
}

class _VetFormDialogState extends State<_VetFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _clinic;
  late final TextEditingController _license;
  late final TextEditingController _specialty;
  late final TextEditingController _address;
  late final TextEditingController _fee;
  late bool _accepting;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _name = TextEditingController(text: v?.name ?? '');
    _email = TextEditingController();
    _password = TextEditingController();
    _clinic = TextEditingController(text: v?.clinicName ?? '');
    _license = TextEditingController();
    _specialty =
        TextEditingController(text: v?.specialty ?? 'General Veterinary Care');
    _address = TextEditingController(text: v?.address ?? '');
    _fee = TextEditingController(text: (v?.fee ?? 500).toString());
    _accepting = v?.isAcceptingBookings ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _password, _clinic, _license, _specialty, _address, _fee
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final missing = _name.text.trim().isEmpty ||
        _clinic.text.trim().isEmpty ||
        (!_isEdit &&
            (_email.text.trim().isEmpty ||
                _password.text.trim().length < 6 ||
                _license.text.trim().isEmpty));
    if (missing) {
      setState(() => _error = _isEdit
          ? 'Doctor name and clinic name are required.'
          : 'Please fill all required fields (password min 6 chars).');
      return;
    }

    Navigator.pop(
      context,
      _VetFormResult(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text.trim(),
        clinicName: _clinic.text.trim(),
        licenseNumber: _license.text.trim(),
        specialty: _specialty.text.trim().isEmpty
            ? 'General Veterinary Care'
            : _specialty.text.trim(),
        address: _address.text.trim().isEmpty ? 'Lalitpur' : _address.text.trim(),
        fee: int.tryParse(_fee.text.trim()) ?? 500,
        isAcceptingBookings: _accepting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.medical_services_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isEdit ? 'Edit Veterinarian' : 'Add Trusted Veterinarian',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_name, 'Doctor Name (e.g. Dr. Aarav Sharma) *'),
            if (!_isEdit) ...[
              _field(_email, 'Clinic Login Email *',
                  type: TextInputType.emailAddress),
              _field(_password, 'Temporary Password (min 6 chars) *',
                  obscure: true),
            ],
            _field(_clinic, 'Clinic Name *'),
            if (!_isEdit) _field(_license, 'Vet Council License No. *'),
            _field(_specialty, 'Specialty'),
            _field(_address, 'Clinic Address (e.g. Jhamsikhel, Lalitpur)'),
            _field(_fee, 'Consultation Fee (₹)', type: TextInputType.number),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accepting bookings',
                    style: TextStyle(fontSize: 14)),
                value: _accepting,
                onChanged: (v) => setState(() => _accepting = v),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!,
                    style:
                    const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(_isEdit ? 'Save Changes' : 'Add Doctor'),
        ),
      ],
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String hint, {
        TextInputType type = TextInputType.text,
        bool obscure = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
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
      ),
    );
  }
}
