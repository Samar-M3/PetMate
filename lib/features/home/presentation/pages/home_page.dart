import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmatee/features/care_events/screens/events_home_screen.dart';
import 'package:petmatee/features/care_events/screens/vet_appts_home_screen.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/in_app_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/pages/chats_page.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/requests_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/home_header.dart';
import '../widgets/swipeable_card_deck.dart';
import '../../../shop/presentation/pages/shop_home_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int _selectedNavIndex = 0;
  final Set<int> _visitedNavTabs = {0};
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
      ref.read(authStateProvider.notifier).refreshUserProfile();
      ref.read(inAppNotificationsProvider.notifier).syncPendingOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
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
        Future.microtask(() {
          if (mounted) ref.read(discoveryProvider.notifier).clearSnackbar();
        });
      }
    });

    final unreadChatsCount = ref.watch(unreadChatsCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Header Section (PetMate logo & user avatar)
            if (_selectedNavIndex != 3)
              HomeHeader(onProfileTap: () => context.push('/profile')),

            // 2. Main Content Area (Discovery Deck or Tab View with Lazy Loading)
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
                  _visitedNavTabs.contains(1)
                      ? const ChatsPage()
                      : const SizedBox.shrink(),

                  // Tab 2: Events (Events Screen)
                  _visitedNavTabs.contains(2)
                      ? const EventsHomeScreen()
                      : const SizedBox.shrink(),

                  // Tab 3: Shop
                  _visitedNavTabs.contains(3)
                      ? const ShopHomePage()
                      : const SizedBox.shrink(),

                  // Tab 4: Vet Appointments (Vet Appts Screen)
                  _visitedNavTabs.contains(4)
                      ? const VetApptsHomeScreen()
                      : const SizedBox.shrink(),
                ],
              ),
            ),

            // 4. Fixed Bottom Navigation Bar
            PetMateBottomNavBar(
              selectedIndex: _selectedNavIndex,
              pendingRequestsCount:
                  requestsState.pendingCount + unreadChatsCount,
              onItemSelected: (index) {
                setState(() {
                  _selectedNavIndex = index;
                  _visitedNavTabs.add(index);
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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terracotta.withValues(alpha: 0.10),
                ),
                child: const Icon(
                  Icons.pets,
                  size: 36,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add a Pet to Start',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your pet profile to discover compatible playdates and friends nearby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  context.push('/onboarding/pet');
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text(
                  'Add Pet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: const Icon(
                  Icons.visibility_off_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Activate a Pet Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'None of your pet profiles are currently active in discovery decks. Activate a pet to meet friends nearby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  context.push('/my-pets');
                },
                icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
                label: const Text(
                  'Manage Pets',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.terracotta,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Finding nearby pets...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
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
                size: 44,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to Load Pets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                discoveryState.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  discoveryNotifier.retryLoad();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SwipeableCardDeck(
        key: _deckKey,
        pets: discoveryState.pets,
        currentIndex: discoveryState.currentIndex,
        onSwipeRight: () => discoveryNotifier.swipeRight(),
        onSwipeLeft: () => discoveryNotifier.swipeLeft(),
        onReset: () => discoveryNotifier.resetDeck(),
      ),
    );
  }
}
