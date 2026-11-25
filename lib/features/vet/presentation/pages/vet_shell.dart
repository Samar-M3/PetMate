import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/screens/vet_management/vet_admin_dashboard.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/vet_first_login_password_dialog.dart';

class VetShell extends ConsumerStatefulWidget {
  const VetShell({super.key});

  @override
  ConsumerState<VetShell> createState() => _VetShellState();
}

class _VetShellState extends ConsumerState<VetShell> {
  bool _passwordDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPasswordSetup());
  }

  Future<void> _showPasswordSetup() async {
    if (!mounted || _passwordDialogShown) return;
    if (ref.read(authStateProvider).user?.mustChangePassword != true) return;

    _passwordDialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VetFirstLoginPasswordDialog(
        onSubmit: ref
            .read(authStateProvider.notifier)
            .completeInitialVeterinarianPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mustChangePassword =
        ref.watch(authStateProvider).user?.mustChangePassword ?? false;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Veterinarian Portal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Log Out',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: mustChangePassword
          ? const SizedBox.expand()
          : const VetAdminDashboard(),
    );
  }
}
