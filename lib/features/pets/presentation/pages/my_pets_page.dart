import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/pets_activation_provider.dart';

class MyPetsPage extends ConsumerStatefulWidget {
  const MyPetsPage({super.key});

  @override
  ConsumerState<MyPetsPage> createState() => _MyPetsPageState();
}

class _MyPetsPageState extends ConsumerState<MyPetsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(petsActivationProvider.notifier).loadSummary();
      ref.read(authStateProvider.notifier).refreshUserProfile();
    });
  }

  Future<void> _handleSwitchToggle({
    required BuildContext context,
    required String petId,
    required String petName,
    required bool currentActive,
  }) async {
    final notifier = ref.read(petsActivationProvider.notifier);

    if (currentActive) {
      try {
        await notifier.toggleActivation(petId: petId, active: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$petName is no longer your active swiping pet.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackbar(context, e.toString());
        }
      }
      return;
    }

    try {
      await notifier.toggleActivation(petId: petId, active: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$petName is now your active pet for swiping!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackbar(context, e.toString());
      }
    }
  }

  void _showErrorSnackbar(BuildContext context, String rawError) {
    final cleanError = rawError.replaceAll('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanError),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userPets = authState.user?.pets ?? [];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'My Pets',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () {
              ref.read(petsActivationProvider.notifier).loadSummary();
              ref.read(authStateProvider.notifier).refreshUserProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pet Cards List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Pet Profiles',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/onboarding/pet'),
                  icon: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.terracotta,
                  ),
                  label: const Text(
                    'Add New Pet',
                    style: TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (userPets.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.pets,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No pets added yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add your pet to start meeting friends nearby!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                      ),
                      onPressed: () => context.push('/onboarding/pet'),
                      child: const Text(
                        'Add My Pet',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (int index = 0; index < userPets.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                _buildPetCard(context, userPets[index]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, dynamic pet) {
    final photo =
        pet.effectiveImageUrl ?? pet.imageUrl ?? pet.profilePictureUrl;
    final active = pet.isActive == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pet Avatar & Info (tap to view pet profile)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/pet/${pet.id}'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.inputFill,
                    backgroundImage: photo != null && photo.isNotEmpty
                        ? NetworkImage(photo)
                        : null,
                    child: photo == null || photo.isEmpty
                        ? const Icon(
                            Icons.pets,
                            color: AppColors.textMuted,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pet.breed ?? 'Unknown Breed'} • ${pet.animalType ?? 'Pet'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Active for swiping chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.textMuted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active
                                    ? Icons.check_circle_outline
                                    : Icons.radio_button_unchecked,
                                size: 12,
                                color: active
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                active ? 'Active for swiping' : 'Not active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: active
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Toggle Switch
          Switch.adaptive(
            value: active,
            activeTrackColor: AppColors.primary,
            onChanged: (_) {
              _handleSwitchToggle(
                context: context,
                petId: pet.id,
                petName: pet.name,
                currentActive: active,
              );
            },
          ),
        ],
      ),
    );
  }
}
