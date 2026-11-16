
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sfiqzoogerojnqelsfxl.supabase.co',
    publishableKey: 'sb_publishable_d4fJCXdGH1Zjvw2OyVkREA_GZWrUmN7',
  );
  print('Supabase initialized successfully!');
  print(supabase.auth.currentUser);

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Supabase Connected!'),
        ),
      ),
    );
  }
}
