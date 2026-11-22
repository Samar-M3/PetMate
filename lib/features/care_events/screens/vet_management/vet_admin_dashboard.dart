import 'package:flutter/material.dart';
import '../../models/app_theme.dart';

class VetAdminDashboard extends StatelessWidget {
  const VetAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        title: const Text('Vet Portal Dashboard', style: TextStyle(color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
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
              Icon(Icons.medical_services_outlined, size: 64, color: CareTheme.deepOlive),
              SizedBox(height: 16),
              Text(
                'Veterinarian Portal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CareTheme.charcoal),
              ),
              SizedBox(height: 8),
              Text(
                'Manage upcoming client bookings, appointment availability, and consult records.',
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
