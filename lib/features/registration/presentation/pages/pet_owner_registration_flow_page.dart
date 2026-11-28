import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/reg_step1_user_info.dart';
import '../widgets/reg_step2_pet_profile.dart';
import '../widgets/reg_step3_mating_details.dart';
import '../widgets/reg_step4_health_vet.dart';
import '../widgets/registration_scaffold.dart';

class PetOwnerRegistrationFlowPage extends ConsumerStatefulWidget {
  final bool addPetOnly;

  const PetOwnerRegistrationFlowPage({
    super.key,
    this.addPetOnly = false,
  });

  @override
  ConsumerState<PetOwnerRegistrationFlowPage> createState() =>
      _PetOwnerRegistrationFlowPageState();
}

class _PetOwnerRegistrationFlowPageState
    extends ConsumerState<PetOwnerRegistrationFlowPage> {
  final _step1Key = GlobalKey<RegStep1UserInfoState>();
  final _step2Key = GlobalKey<RegStep2PetProfileState>();
  final _step3Key = GlobalKey<RegStep3MatingDetailsState>();
  final _step4Key = GlobalKey<RegStep4HealthVetState>();

  @override
  void initState() {
    super.initState();
    // If the user is already authenticated (e.g., resumed after logging in),
    // load saved profile and pet data to resume at the saved step.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.addPetOnly) {
        ref.read(registrationProvider.notifier).startAddPetFlow();
        return;
      }
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated) {
        ref.read(registrationProvider.notifier).loadSavedProgress();
      }
    });
  }

  void _onNext(int currentStep) {
    switch (currentStep) {
      case 1:
        _step1Key.currentState?.submit();
        break;
      case 2:
        _step2Key.currentState?.submit();
        break;
      case 3:
        _step3Key.currentState?.submit();
        break;
      case 4:
        _step4Key.currentState?.submit();
        break;
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.addPetOnly
                    ? 'Pet Profile Added!'
                    : 'Registration Complete!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.addPetOnly
                    ? 'Your new pet profile is ready and added to your account.'
                    : 'Your pet parent account and pet profile are ready. Welcome to the PetMate Nepal family!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (widget.addPetOnly) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    } else {
                      context.go('/');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.addPetOnly ? 'Done' : 'Go to Home',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final regState = ref.watch(registrationProvider);

    // Listen for completion
    ref.listen<RegistrationState>(registrationProvider, (prev, next) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _showCompletionDialog();
      }
    });

    if (regState.isLoading ||
        (!widget.addPetOnly &&
            authState.isAuthenticated &&
            regState.profile == null &&
            regState.errorMessage == null)) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final step = widget.addPetOnly
        ? regState.currentStep.clamp(2, 4)
        : regState.currentStep.clamp(1, 4);

    String title;
    String subtitle;
    Widget bodyWidget;
    VoidCallback? onSkip;

    switch (step) {
      case 1:
        title = authState.isAuthenticated
            ? 'Complete Your Profile'
            : 'Create Your Account';
        subtitle = authState.isAuthenticated
            ? 'Confirm your name, mobile number, and district to continue.'
            : 'Let\'s get you set up with a PetMate pet owner profile.';
        bodyWidget = RegStep1UserInfo(key: _step1Key);
        onSkip = null;
        break;
      case 2:
        title = 'Tell Us About Your Pet';
        subtitle = 'Create your pet\'s primary profile for mating and health.';
        bodyWidget = RegStep2PetProfile(key: _step2Key);
        onSkip = null;
        break;
      case 3:
        title = 'Mating & Personality';
        subtitle = 'Help other pet parents discover your pet for mating or playdates.';
        bodyWidget = RegStep3MatingDetails(key: _step3Key);
        onSkip = () => ref.read(registrationProvider.notifier).skipStep3();
        break;
      case 4:
      default:
        title = 'Health & Vet Details';
        subtitle = 'Vaccination history and private health documentation.';
        bodyWidget = RegStep4HealthVet(key: _step4Key);
        onSkip = () =>
            ref.read(registrationProvider.notifier).submitStep4AndComplete(null);
        break;
    }

    return RegistrationScaffold(
      currentStep: widget.addPetOnly ? step - 1 : step,
      totalSteps: widget.addPetOnly ? 3 : 4,
      title: title,
      subtitle: subtitle,
      body: bodyWidget,
      onBack: widget.addPetOnly
          ? (step > 2
              ? () => ref.read(registrationProvider.notifier).goBack()
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                })
          : (step > 1
              ? () => ref.read(registrationProvider.notifier).goBack()
              : () async {
                  if (authState.isAuthenticated) {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  } else {
                    context.go('/register');
                  }
                }),
      onNext: () => _onNext(step),
      onSkip: onSkip,
      onRetry: () => _onNext(step),
      isSaving: regState.isSaving,
      errorMessage: regState.errorMessage,
      canResumeLogin: regState.canResumeLogin,
      onLoginToResume: () => context.go('/login'),
      nextButtonText:
          step == 4 ? (widget.addPetOnly ? 'Save Pet' : 'Get Started') : 'Next',
    );
  }
}
