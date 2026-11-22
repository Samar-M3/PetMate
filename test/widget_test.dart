import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/app.dart';
import 'package:petmatee/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PetMateApp smoke test renders title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const PetMateApp(),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    // Verify PetMate app renders
    expect(find.text('PetMate'), findsWidgets);
  });
}
