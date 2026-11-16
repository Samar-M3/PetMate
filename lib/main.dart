
import 'package:flutter/material.dart';

void main() {
  runApp(const PetMateApp());
}

class PetMateApp extends StatelessWidget {
  const PetMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('PetMate'),
        ),
      ),
    );
  }
}
