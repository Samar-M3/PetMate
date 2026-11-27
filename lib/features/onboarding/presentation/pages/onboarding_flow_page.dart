import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/step1_user_info.dart';
import '../widgets/step2_pet_profile.dart';
import '../widgets/step3_mating_details.dart';
import '../widgets/step4_health_vet.dart';

class OnboardingFlowPage extends ConsumerWidget {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    if (state.isLoading && state.profile == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 14),
              Text(
                'Loading your setup...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.profile == null && state.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(onboardingProvider.notifier).loadInitialState(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    switch (state.currentStep) {
      case 1:
        return const Step1UserInfo();
      case 2:
        return const Step2PetProfile();
      case 3:
        return const Step3MatingDetails();
      case 4:
        return const Step4HealthVet();
      default:
        return const Step1UserInfo();
    }
  }
}
