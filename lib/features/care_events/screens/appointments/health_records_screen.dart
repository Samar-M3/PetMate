import 'package:flutter/material.dart';
import '../../models/app_theme.dart';

class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: const Text('Pet Health Records', style: TextStyle(color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.health_and_safety, size: 64, color: CareTheme.deepOlive),
              SizedBox(height: 16),
              Text(
                'Health Records & Vaccines',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CareTheme.charcoal),
              ),
              SizedBox(height: 8),
              Text(
                'Your pet vaccination records and vet consultation notes will be organized here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CareTheme.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
