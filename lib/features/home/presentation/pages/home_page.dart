import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../care_events/screens/events_home_screen.dart';
import '../../../care_events/screens/vet_appts_home_screen.dart';
import '../../../chat/presentation/pages/chats_page.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/requests_provider.dart';
import '../widgets/action_buttons.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/home_header.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/swipeable_card_deck.dart';
import '../widgets/tab_placeholders.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int _selectedNavIndex = 0;
  final GlobalKey<SwipeableCardDeckState> _deckKey =
      GlobalKey<SwipeableCardDeckState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestsProvider.notifier).loadRequests();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(requestsProvider.notifier).loadRequests(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final allUserPets = user?.pets ?? [];
    final userPets = allUserPets.where((p) => p.isActive).toList();
    final discoveryState = ref.watch(discoveryProvider);
    final discoveryNotifier = ref.read(discoveryProvider.notifier);
    final requestsState = ref.watch(requestsProvider);

    // Auto-initialize feed for user's primary active pet
    if (userPets.isNotEmpty &&
        (discoveryState.activePetId == null ||
            !userPets.any((p) => p.id == discoveryState.activePetId)) &&
        !discoveryState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        discoveryNotifier.setActivePet(userPets.first.id);
      });
    } else if (userPets.isEmpty && discoveryState.activePetId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        discoveryNotifier.clearActivePet();
      });
    }

    // Listen for background swipe errors and display friendly snackbars
    ref.listen<DiscoveryState>(discoveryProvider, (previous, next) {
      if (next.snackbarMessage != null &&
          next.snackbarMessage != previous?.snackbarMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.snackbarMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(discoveryProvider.notifier).clearSnackbar();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Header Section (PetMate logo & user avatar)
            HomeHeader(onProfileTap: () => ProfileBottomSheet.show(context)),

            // 2. Active Pet Switcher (if user has several pets)
            if (userPets.length > 1 && _selectedNavIndex == 0)
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: userPets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final pet = userPets[index];
                    final isSelected = pet.id == discoveryState.activePetId;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pets, size: 14),
                          const SizedBox(width: 5),
                          Text(pet.name),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.terracotta.withValues(
                        alpha: 0.18,
                      ),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.terracotta
                            : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.terracotta
                            : AppColors.border,
                        width: 1.2,
                      ),
                      onSelected: (_) {
                        discoveryNotifier.setActivePet(pet.id);
                      },
                    );
                  },
                ),
              ),

            // 3. Main Content Area (Discovery Deck or Tab View)
            Expanded(
              child: IndexedStack(
                index: _selectedNavIndex,
                children: [
                  // Tab 0: Home (Real Discover Feed)
                  _buildDiscoveryTab(
                    context: context,
                    allPetsCount: allUserPets.length,
                    activePetsCount: userPets.length,
                    discoveryState: discoveryState,
                    discoveryNotifier: discoveryNotifier,
                  ),

                  // Tab 1: Chats & Matches (with Requests in top right)
                  const ChatsPage(),

                  // Tab 2: Events (Your Events Screen)
                  const EventsHomeScreen(),

                  // Tab 3: Shop
                  const TabPlaceholderView(
                    title: 'Pet Marketplace',
                    subtitle: 'Browse quality food, toys, health products, and accessories for your pets.',
                    icon: Icons.shopping_bag_rounded,
                    iconColor: Color(0xFFE68A00),
                  ),

                  // Tab 4: Vet Appointments (Your Vet Appts Screen)
                  const VetApptsHomeScreen(),
                ],
              ),
            ),

            // 4. Fixed Bottom Navigation Bar
            PetMateBottomNavBar(
              selectedIndex: _selectedNavIndex,
              pendingRequestsCount: requestsState.pendingCount,
              onItemSelected: (index) {
                setState(() {
                  _selectedNavIndex = index;
                });
                if (index == 1) {
                  ref
                      .read(chatConversationsProvider.notifier)
                      .loadConversations();
                  ref
                      .read(requestsProvider.notifier)
                      .loadRequests(refresh: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryTab({
    required BuildContext context,
    required int allPetsCount,
    required int activePetsCount,
    required DiscoveryState discoveryState,
    required DiscoveryNotifier discoveryNotifier,
  }) {
    // State A: User has zero pets registered
    if (allPetsCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.pets,
                  size: 48,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add a Pet to Start',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You don\'t have any pets registered yet. Add your pet\'s profile to discover friends and playdates nearby!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 3,
                ),
                onPressed: () {
                  context.push('/onboarding/pet');
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text(
                  'Add My Pet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State A2: User has registered pets but NONE are active in deck
    if (activePetsCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.visibility_off_rounded,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Turn on a pet to start swiping',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'None of your pet profiles are currently active in discovery decks. Activate a pet to meet friends nearby!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 3,
                ),
                onPressed: () {
                  context.push('/my-pets');
                },
                icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                label: const Text(
                  'Manage My Pets',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State B: Initial Loading State
    if (discoveryState.isLoading && discoveryState.pets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.terracotta),
            SizedBox(height: 16),
            Text(
              'Finding nearby pets...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // State C: Error State
    if (discoveryState.errorMessage != null && discoveryState.pets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 54,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                discoveryState.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  discoveryNotifier.resetDeck();
                },
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State D: Normal deck with cards or empty deck state
    return Column(
      children: [
        // Large Swipeable Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwipeableCardDeck(
              key: _deckKey,
              pets: discoveryState.pets,
              currentIndex: discoveryState.currentIndex,
              onSwipeRight: () => discoveryNotifier.swipeRight(),
              onSwipeLeft: () => discoveryNotifier.swipeLeft(),
              onReset: () => discoveryNotifier.resetDeck(),
            ),
          ),
        ),

        // Two Action Buttons: Pass (X) and Like (Heart)
        ActionButtons(
          enabled: discoveryState.hasMore,
          onPass: () {
            _deckKey.currentState?.swipeLeftProgrammatic();
          },
          onLike: () {
            _deckKey.currentState?.swipeRightProgrammatic();
          },
        ),
      ],
    );
  }
}
