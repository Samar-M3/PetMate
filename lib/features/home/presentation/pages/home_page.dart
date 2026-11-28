import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmatee/features/care_events/screens/vet_appts_home_screen.dart';
import 'package:petmatee/features/shop/presentation/pages/shop_home_page.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/in_app_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../chat/presentation/pages/chats_page.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../providers/discovery_provider.dart';
import '../providers/requests_provider.dart';
import '../../data/repositories/matching_repository.dart';
import '../../../chat/presentation/providers/connections_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/discover_paw_background.dart';
import '../widgets/home_header.dart';
import '../widgets/intro_message_sheet.dart';
import '../widgets/like_success_notification.dart';
import '../widgets/pet_switcher_overlay.dart';
import '../widgets/swipeable_card_deck.dart';

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
  final GlobalKey _profileNavKey = GlobalKey();

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
    PetSwitcherOverlay.dismissImmediate();
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
    final allUserPets = user?.pets ?? <PetEntity>[];
    final userPets = allUserPets;
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

    // Compute active pet & profile avatar info for bottom nav
    PetEntity? activePet;
    for (final p in userPets) {
      if (p.id == discoveryState.activePetId) {
        activePet = p;
        break;
      }
    }
    activePet ??= userPets.isNotEmpty ? userPets.first : null;

    final profile = user?.profile;
    final avatarUrl = activePet?.effectiveImageUrl ??
        profile?.effectiveImageUrl ??
        profile?.profilePictureUrl;
    final profileInitial = (activePet != null && activePet.name.isNotEmpty)
        ? activePet.name[0].toUpperCase()
        : (profile?.fullName != null && profile!.fullName!.isNotEmpty)
            ? profile.fullName![0].toUpperCase()
            : (user?.email != null && user!.email!.isNotEmpty)
                ? user.email![0].toUpperCase()
                : 'P';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      body: DiscoverPawBackground(
        enabled: _selectedNavIndex == 0,
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            // 1. Top Header Section (PetMate logo, notification bell, location)
            if (_selectedNavIndex != 2 && _selectedNavIndex != 4)
              const HomeHeader(),

            // 2. Main Content Area (Discovery Deck or Tab View with Lazy Loading)
            Expanded(
              child: IndexedStack(
                index: _selectedNavIndex,
                children: [
                  // Tab 0: Discover Feed
                  _buildDiscoveryTab(
                    context: context,
                    allPetsCount: allUserPets.length,
                    activePetsCount: userPets.length,
                    discoveryState: discoveryState,
                    discoveryNotifier: discoveryNotifier,
                    userPets: userPets,
                  ),

                  // Tab 1: Chats & Matches
                  _visitedNavTabs.contains(1)
                      ? const ChatsPage()
                      : const SizedBox.shrink(),

                  // Tab 2: Shop
                  _visitedNavTabs.contains(2)
                      ? const ShopHomePage()
                      : const SizedBox.shrink(),

                  // Tab 3: Vets
                  _visitedNavTabs.contains(3)
                      ? const VetApptsHomeScreen()
                      : const SizedBox.shrink(),

                  // Tab 4: Profile
                  _visitedNavTabs.contains(4)
                      ? const ProfilePage(embeddedInTab: true)
                      : const SizedBox.shrink(),
                ],
              ),
            ),

            // 4. Fixed Bottom Navigation Bar
            PetMateBottomNavBar(
              selectedIndex: _selectedNavIndex,
              pendingRequestsCount:
                  requestsState.pendingCount + unreadChatsCount,
              avatarUrl: avatarUrl,
              profileInitial: profileInitial,
              profileItemKey: _profileNavKey,
              onProfileLongPressStart: userPets.length > 1
                  ? (globalPos) {
                      final renderBox = _profileNavKey.currentContext
                          ?.findRenderObject() as RenderBox?;
                      if (renderBox == null) return;
                      PetSwitcherOverlay.show(
                        context: context,
                        anchor: renderBox,
                        pets: userPets,
                        activePetId: activePet?.id,
                        onPetSelected: (petId) {
                          discoveryNotifier.setActivePet(petId);
                        },
                      );
                      PetSwitcherOverlay.updateDrag(globalPos);
                    }
                  : null,
              onProfileLongPressMove: userPets.length > 1
                  ? PetSwitcherOverlay.updateDrag
                  : null,
              onProfileLongPressEnd: userPets.length > 1
                  ? PetSwitcherOverlay.endDrag
                  : null,
              onProfileLongPressCancel: userPets.length > 1
                  ? PetSwitcherOverlay.cancel
                  : null,
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
                  ref
                      .read(outgoingRequestsProvider.notifier)
                      .loadOutgoingRequests(refresh: true);
                  ref.invalidate(allConnectionsProvider);
                }
              },
            ),
          ],
        ),
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
    required List<PetEntity> userPets,
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

    // Get active pet for species filtering
    PetEntity? activePet;
    for (final p in userPets) {
      if (p.id == discoveryState.activePetId) {
        activePet = p;
        break;
      }
    }
    activePet ??= userPets.isNotEmpty ? userPets.first : null;
    final activePetSpecies = activePet?.animalType;

    // Build filter tabs
    final isForYou = discoveryState.currentFilter == DiscoveryFilter.forYou;
    final canUseForYou = activePetSpecies != null && activePetSpecies.isNotEmpty;

    return Column(
      children: [
        // Compact centered All / For You segmented control
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: FractionallySizedBox(
                widthFactor: 0.78,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A2926).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        alignment: isForYou
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          heightFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE16F52),
                              borderRadius: BorderRadius.circular(19),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildFilterTab(
                            label: 'All',
                            isSelected: !isForYou,
                            onTap: () => discoveryNotifier
                                .setFilter(DiscoveryFilter.all),
                          ),
                          _buildFilterTab(
                            label: 'For You',
                            isSelected: isForYou,
                            onTap: () {
                              if (canUseForYou) {
                                discoveryNotifier.setFilter(
                                  DiscoveryFilter.forYou,
                                  species: activePetSpecies,
                                );
                              } else {
                                discoveryNotifier
                                    .setFilter(DiscoveryFilter.all);
                              }
                            },
                            isEnabled: canUseForYou,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Content based on filter
        Expanded(
          child: _buildFilterContent(
            context: context,
            discoveryState: discoveryState,
            discoveryNotifier: discoveryNotifier,
            activePetSpecies: activePetSpecies,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return Expanded(
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : isEnabled
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContent({
    required BuildContext context,
    required DiscoveryState discoveryState,
    required DiscoveryNotifier discoveryNotifier,
    required String? activePetSpecies,
  }) {
    final isForYou = discoveryState.currentFilter == DiscoveryFilter.forYou;
    final isLoading = isForYou ? discoveryState.isForYouLoading : discoveryState.isLoading;
    final pets = isForYou ? discoveryState.forYouPets : discoveryState.pets;
    final currentIndex = isForYou ? discoveryState.forYouCurrentIndex : discoveryState.currentIndex;
    final errorMessage = discoveryState.errorMessage;

    // State B: Initial Loading State
    if (isLoading && pets.isEmpty) {
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
    if (errorMessage != null && pets.isEmpty) {
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
                errorMessage,
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

// State D: Empty state
    if (pets.isEmpty) {
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
                  color: AppColors.textMuted.withValues(alpha: 0.10),
                ),
                child: Icon(
                  isForYou ? Icons.favorite_border : Icons.pets_outlined,
                  size: 36,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isForYou ? 'No Recommendations Yet' : 'No Pets Found',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isForYou
                    ? 'No ${activePetSpecies != null ? activePetSpecies.toLowerCase() : 'pet'} recommendations available right now. Check back later!'
                    : 'No pets found nearby. Try again later or adjust your preferences.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                  discoveryNotifier.resetDeck();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Refresh',
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

    // State E: Normal deck with cards + Like Success Notification
    final likeEvent = discoveryState.likeSuccessEvent;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SwipeableCardDeck(
            key: _deckKey,
            pets: pets,
            currentIndex: currentIndex,
            onSwipeRight: () => discoveryNotifier.swipeRight(),
            onSwipeLeft: () => discoveryNotifier.swipeLeft(),
            onReset: () => discoveryNotifier.resetDeck(),
          ),
        ),
        if (likeEvent != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: LikeSuccessNotification(
              key: ValueKey(likeEvent.eventId),
              event: likeEvent,
              onDismiss: () => discoveryNotifier.clearLikeEvent(),
              onOpenMatchChat: () {
                discoveryNotifier.clearLikeEvent();
                if (likeEvent.matchId != null &&
                    likeEvent.matchId!.isNotEmpty) {
                  context.push('/chat/${likeEvent.matchId}');
                }
              },
              onAddMessage: () {
                final reqId = likeEvent.requestId;
                discoveryNotifier.clearLikeEvent();
                if (reqId == null || reqId.isEmpty) return;

                showIntroMessageSheet(
                  context: context,
                  petName: likeEvent.petName,
                  petImageUrl: likeEvent.petImageUrl,
                  onSend: (msg) async {
                    await ref
                        .read(matchingRepositoryProvider)
                        .updateIntroMessage(requestId: reqId, message: msg);
                    ref
                        .read(outgoingRequestsProvider.notifier)
                        .loadOutgoingRequests(refresh: true);
                    ref.invalidate(allConnectionsProvider);
                  },
                ).then((sent) {
                  if (sent != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Intro message sent to ${likeEvent.petName}!',
                        ),
                        backgroundColor: const Color(0xFF0F5C57),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                });
              },
            ),
          ),
      ],
    );
  }
}
