import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/models/vet_model.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';

import '../theme/admin_colors.dart';

class AdminVetsTab extends ConsumerStatefulWidget {
  const AdminVetsTab({super.key});

  @override
  ConsumerState<AdminVetsTab> createState() => _AdminVetsTabState();
}

class _AdminVetsTabState extends ConsumerState<AdminVetsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AdminColors.error : AdminColors.success,
      ),
    );
  }

  Future<void> _addVet() async {
    final form = await showDialog<_VetFormResult>(
      context: context,
      builder: (_) => const _VetFormDialog(),
    );
    if (form == null) return;

    try {
      await ref
          .read(veterinariansProvider.notifier)
          .addVeterinarian(
            name: form.name,
            email: form.email,
            password: form.password,
            clinicName: form.clinicName,
            licenseNumber: form.licenseNumber,
            specialty: form.specialty,
            address: form.address,
            fee: form.fee,
            isAcceptingBookings: form.isAcceptingBookings,
          );
      _snack('Trusted veterinarian added successfully!');
    } catch (e) {
      _snack('Failed to add veterinarian: $e', error: true);
    }
  }

  Future<void> _editVet(Vet vet) async {
    final form = await showDialog<_VetFormResult>(
      context: context,
      builder: (_) => _VetFormDialog(existing: vet),
    );
    if (form == null) return;

    try {
      await ref
          .read(veterinariansProvider.notifier)
          .updateVeterinarian(
            vet.id,
            name: form.name,
            clinicName: form.clinicName,
            specialty: form.specialty,
            address: form.address,
            fee: form.fee,
            isAcceptingBookings: form.isAcceptingBookings,
          );
      _snack('Veterinarian updated successfully!');
    } catch (e) {
      _snack('Failed to update veterinarian: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vetsAsync = ref.watch(veterinariansProvider);

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: AdminColors.surface,
              border: Border(
                bottom: BorderSide(color: AdminColors.border, width: 1.0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim().toLowerCase());
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search by doctor name, clinic, or specialty...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AdminColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AdminColors.textMuted,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                color: AdminColors.textMuted,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AdminColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AdminColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AdminColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AdminColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: _addVet,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Veterinarian'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: vetsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.primary),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AdminColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading veterinarians: $err',
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(veterinariansProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (vets) {
                final filtered = vets.where((v) {
                  if (_searchQuery.isEmpty) return true;
                  return v.name.toLowerCase().contains(_searchQuery) ||
                      v.clinicName.toLowerCase().contains(_searchQuery) ||
                      v.specialty.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: const Icon(
                            Icons.medical_services_outlined,
                            size: 36,
                            color: AdminColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No veterinarians found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "+ Add Veterinarian" to onboard a verified doctor.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth >= 850;

                    return RefreshIndicator(
                      color: AdminColors.primary,
                      onRefresh: () async =>
                          ref.read(careVetsProvider.notifier).refresh(),
                      child: isWideScreen
                          ? _buildDataTable(filtered)
                          : _buildCardList(filtered),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Vet> vets) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: AdminColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'VETERINARIAN & CLINIC',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'SPECIALTY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'ADDRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'FEE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'ACTIONS',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AdminColors.border),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vets.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.borderLight,
              ),
              itemBuilder: (context, index) {
                final vet = vets[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: AdminColors.primaryLight,
                              child: const Icon(
                                Icons.medical_services_outlined,
                                size: 16,
                                color: AdminColors.primary,
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AdminColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    vet.clinicName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          vet.specialty,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          vet.address,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AdminColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '₹${vet.fee}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.primaryDark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusPill(vet.isAcceptingBookings),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AdminColors.textSecondary,
                            ),
                            tooltip: 'Edit details',
                            onPressed: () => _editVet(vet),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(List<Vet> vets) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: vets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final vet = vets[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AdminColors.primaryLight,
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 18,
                      color: AdminColors.primary,
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vet.clinicName} • ${vet.specialty}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(vet.isAcceptingBookings),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.borderLight,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${vet.address} • Fee: ₹${vet.fee}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _editVet(vet),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AdminColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(bool isAccepting) {
    final color = isAccepting ? AdminColors.success : AdminColors.warning;
    final bg = isAccepting
        ? AdminColors.successLight
        : AdminColors.warningLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isAccepting ? 'Verified' : 'Paused',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
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
    _specialty = TextEditingController(
      text: v?.specialty ?? 'General Veterinary',
    );
    _address = TextEditingController(text: v?.address ?? '');
    _fee = TextEditingController(text: v != null ? '${v.fee}' : '500');
    _accepting = v?.isAcceptingBookings ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _clinic.dispose();
    _license.dispose();
    _specialty.dispose();
    _address.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final clinic = _clinic.text.trim();
    final spec = _specialty.text.trim();
    final addr = _address.text.trim();
    final fee = int.tryParse(_fee.text.trim()) ?? 0;

    if (name.isEmpty || clinic.isEmpty || spec.isEmpty || addr.isEmpty) {
      setState(() => _error = 'Please fill all required fields');
      return;
    }

    if (!_isEdit) {
      final email = _email.text.trim();
      final password = _password.text;
      final license = _license.text.trim();
      if (email.isEmpty ||
          !email.contains('@') ||
          password.length < 8 ||
          password.length > 128 ||
          !RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) {
        setState(
          () => _error = 'Enter a valid email and a temporary password with 8+ characters, a letter, and a number',
        );
        return;
      }
      Navigator.of(context).pop(
        _VetFormResult(
          name: name,
          email: email,
          password: password,
          clinicName: clinic,
          licenseNumber: license,
          specialty: spec,
          address: addr,
          fee: fee,
          isAcceptingBookings: _accepting,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _VetFormResult(
        name: name,
        clinicName: clinic,
        specialty: spec,
        address: addr,
        fee: fee,
        isAcceptingBookings: _accepting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEdit ? 'Edit Veterinarian' : 'Add Veterinarian',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AdminColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _field(_name, 'Doctor Name *'),
                if (!_isEdit) ...[
                  const SizedBox(height: 10),
                  _field(
                    _email,
                    'Login Email *',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _password,
                    'Temporary Password * (8+ characters, letter and number)',
                    obscure: true,
                  ),
                  const SizedBox(height: 10),
                  _field(_license, 'Medical License #'),
                ],
                const SizedBox(height: 10),
                _field(_clinic, 'Clinic Name *'),
                const SizedBox(height: 10),
                _field(_specialty, 'Specialty *'),
                const SizedBox(height: 10),
                _field(_address, 'Clinic Address *'),
                const SizedBox(height: 10),
                _field(
                  _fee,
                  'Consultation Fee (₹) *',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Accepting Bookings',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Allow pet parents to schedule appointments',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                  value: _accepting,
                  activeThumbColor: AdminColors.primary,
                  onChanged: (val) => setState(() => _accepting = val),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AdminColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(_isEdit ? 'Save Changes' : 'Add Doctor'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AdminColors.textSecondary,
        ),
        filled: true,
        fillColor: AdminColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.primary),
        ),
      ),
    );
  }
}
