import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/screens/vet_management/vet_admin_dashboard.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class VetShell extends ConsumerWidget {
  const VetShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: const VetAdminDashboard(),
    );
  }
}
