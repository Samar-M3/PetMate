import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../care_events/screens/events_home_screen.dart';
import '../../../care_events/screens/vet_appts_home_screen.dart';
import '../providers/discovery_provider.dart';
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

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedNavIndex = 0;
  final GlobalKey<SwipeableCardDeckState> _deckKey =
  GlobalKey<SwipeableCardDeckState>();

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);
    final discoveryNotifier = ref.read(discoveryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Header Section (PetMate logo & user avatar)
            HomeHeader(
              onProfileTap: () => ProfileBottomSheet.show(context),
            ),

            // 2. Main Content Area (Discovery Deck or Tab View)
            Expanded(
              child: IndexedStack(
                index: _selectedNavIndex,
                children: [
                  // Tab 0: Home (Tinder-style Discovery)
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                  ),

                  // Tab 1: Chat
                  const TabPlaceholderView(
                    title: 'PetMate Chat',
                    subtitle:
                    'Chat and communicate with owners after confirming a successful match!',
                    icon: Icons.chat_bubble_rounded,
                    iconColor: AppColors.terracotta,
                  ),

                  // Tab 2: Events (Your Events Screen)
                  const EventsHomeScreen(),

                  // Tab 3: Shop
                  const TabPlaceholderView(
                    title: 'Pet Marketplace',
                    subtitle:
                    'Browse quality food, toys, health products, and accessories for your pets.',
                    icon: Icons.shopping_bag_rounded,
                    iconColor: Color(0xFFE68A00),
                  ),

                  // Tab 4: Vet Appointments (Your Vet Appts Screen)
                  const VetApptsHomeScreen(),
                ],
              ),
            ),

            // 3. Fixed Bottom Navigation Bar (5 Items in exact order)
            PetMateBottomNavBar(
              selectedIndex: _selectedNavIndex,
              onItemSelected: (index) {
                setState(() {
                  _selectedNavIndex = index;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
