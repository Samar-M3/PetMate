import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/features/auth/domain/entities/user_entity.dart';
import 'package:petmatee/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:petmatee/features/home/presentation/widgets/pet_switcher_overlay.dart';

void main() {
  testWidgets('Normal tap selects Profile tab without opening switcher',
      (tester) async {
    final profileKey = GlobalKey();
    int? tappedIndex;

    final pets = [
      const PetEntity(id: 'pet-1', userId: 'u1', name: 'Sagun', isActive: true),
      const PetEntity(id: 'pet-2', userId: 'u1', name: 'Bella', isActive: true),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: Builder(
            builder: (context) => PetMateBottomNavBar(
              selectedIndex: 0,
              onItemSelected: (index) => tappedIndex = index,
              profileItemKey: profileKey,
              onProfileLongPressStart: (globalPos) {
                final renderBox =
                    profileKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                PetSwitcherOverlay.show(
                  context: context,
                  anchor: renderBox,
                  pets: pets,
                  activePetId: 'pet-1',
                  onPetSelected: (_) {},
                );
              },
              onProfileLongPressMove: PetSwitcherOverlay.updateDrag,
              onProfileLongPressEnd: PetSwitcherOverlay.endDrag,
              onProfileLongPressCancel: PetSwitcherOverlay.cancel,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 4);
    expect(PetSwitcherOverlay.isShowing, isFalse);
  });

  testWidgets(
      'Long pressing Profile for 350ms shows PetSwitcherOverlay, drag selects pet, release outside cancels',
      (tester) async {
    final profileKey = GlobalKey();
    String? selectedPetId;
    int? tappedIndex;

    final pets = [
      const PetEntity(id: 'pet-1', userId: 'u1', name: 'Sagun', isActive: true),
      const PetEntity(id: 'pet-2', userId: 'u1', name: 'Bella', isActive: true),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: Builder(
            builder: (context) => PetMateBottomNavBar(
              selectedIndex: 0,
              onItemSelected: (index) => tappedIndex = index,
              profileItemKey: profileKey,
              onProfileLongPressStart: (globalPos) {
                final renderBox =
                    profileKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                PetSwitcherOverlay.show(
                  context: context,
                  anchor: renderBox,
                  pets: pets,
                  activePetId: 'pet-1',
                  onPetSelected: (id) => selectedPetId = id,
                );
              },
              onProfileLongPressMove: PetSwitcherOverlay.updateDrag,
              onProfileLongPressEnd: PetSwitcherOverlay.endDrag,
              onProfileLongPressCancel: PetSwitcherOverlay.cancel,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.text('Profile'));
    final gesture = await tester.startGesture(center);

    // Before 350ms: overlay should NOT be showing
    await tester.pump(const Duration(milliseconds: 150));
    expect(PetSwitcherOverlay.isShowing, isFalse);

    // After 350ms: overlay SHOULD be showing, normal tap must NOT trigger
    await tester.pump(const Duration(milliseconds: 250));
    expect(PetSwitcherOverlay.isShowing, isTrue);
    expect(tappedIndex, isNull);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Drag to second pet avatar (the one showing 'B' initial) and release
    final bellaCenter = tester.getCenter(find.text('B'));
    await gesture.moveTo(bellaCenter);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Bella'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(PetSwitcherOverlay.isShowing, isFalse);
    expect(selectedPetId, 'pet-2');
    expect(tappedIndex, isNull);
  });
}
