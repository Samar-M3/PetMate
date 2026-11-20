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
    });
  }

  Future<void> _handleSwitchToggle({
    required BuildContext context,
    required String petId,
    required String petName,
    required bool currentActive,
  }) async {
    final notifier = ref.read(petsActivationProvider.notifier);
    final summary = ref.read(petsActivationProvider).summary;
    final allowedActive = summary?.allowedActive ?? 1;
    final activePets = summary?.activePets ?? [];

    // Case 1: Turning OFF is always allowed directly
    if (currentActive) {
      try {
        await notifier.toggleActivation(petId: petId, active: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$petName is now hidden from discovery decks.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed: ${e.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    // Case 2: Turning ON when 1 allowed slot and an active pet already exists -> Prompt Confirmation
    if (allowedActive == 1 && activePets.isNotEmpty) {
      final activePet = activePets.first;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Swap Active Pet?'),
          content: Text(
            'Turning on $petName will turn off ${activePet.name}.\n\nOnly one pet profile can be visible in discovery decks with your current free slot.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Turn On $petName',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      try {
        await notifier.toggleActivation(petId: petId, active: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$petName is now active in discovery decks!'),
              backgroundColor: AppColors.success,
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

    // Case 3: Several slots exist and all are currently used -> Prompt which pet to turn off or buy slot
    if (allowedActive > 1 && activePets.length >= allowedActive) {
      final selectedPetId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Active Limit Reached'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All $allowedActive of your active pet slots are currently in use. Choose which pet to turn off to activate $petName:',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ...activePets.map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage:
                        p.imageUrl != null && p.imageUrl!.isNotEmpty
                        ? NetworkImage(p.imageUrl!)
                        : null,
                    child: p.imageUrl == null
                        ? Text(
                            p.name[0],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(p.breed ?? p.animalType ?? 'Pet'),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => Navigator.pop(ctx, p.id),
                    child: const Text('Deactivate'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/slots');
              },
              child: const Text(
                'Get More Slots',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (selectedPetId == null) return;

      try {
        await notifier.toggleActivation(
          petId: petId,
          active: true,
          deactivatePetId: selectedPetId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$petName activated successfully!'),
              backgroundColor: AppColors.success,
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

    // Default Case: Empty slot available -> activate directly
    try {
      await notifier.toggleActivation(petId: petId, active: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$petName activated in discovery decks!'),
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
    final activationState = ref.watch(petsActivationProvider);
    final summary = activationState.summary;

    final allowed = summary?.allowedActive ?? 1;
    final activeCount =
        summary?.activeCount ?? userPets.where((p) => p.isActive).length;

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
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Slots Summary Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.visibility_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Deck Visibility Slots',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '$activeCount of $allowed active in deck',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.terracotta,
                            minimumSize: const Size(80, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            context.push('/slots');
                          },
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Get More',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (summary?.expiringSoonWarning != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              summary!.expiringSoonWarning!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (summary?.recentDowngradeMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              summary!.recentDowngradeMessage!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Pet Cards List
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
    final photo = pet.effectiveImageUrl ?? pet.imageUrl ?? pet.profilePictureUrl;
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
          // Pet Avatar
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

          // Pet Info
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
                // Visible in deck chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.success.withValues(
                            alpha: 0.12,
                          )
                        : AppColors.textMuted.withValues(
                            alpha: 0.15,
                          ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? Icons.visibility : Icons.visibility_off,
                        size: 12,
                        color: active ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        active ? 'Visible in deck' : 'Hidden from deck',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              active ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
