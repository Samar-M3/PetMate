import 'package:flutter/material.dart';

import '../../models/app_theme.dart';
import '../../models/mock_care_data.dart';
import '../../models/vet_model.dart';

class VetProfileFormScreen extends StatefulWidget {
  const VetProfileFormScreen({super.key});

  @override
  State<VetProfileFormScreen> createState() => _VetProfileFormScreenState();
}

class _VetProfileFormScreenState extends State<VetProfileFormScreen> {
  final _nameCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '500');

  void _saveVet() {
    if (_nameCtrl.text.isEmpty || _clinicCtrl.text.isEmpty) return;

    MockCareData.vets.add(
      Vet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        clinicName: _clinicCtrl.text.trim(),
        specialty: _specCtrl.text.trim().isEmpty
            ? 'General Care'
            : _specCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? 'Lalitpur'
            : _addressCtrl.text.trim(),
        rating: 5.0,
        fee: int.tryParse(_feeCtrl.text) ?? 500,
        availableSlots: ['10:00 AM', '02:00 PM', '04:00 PM'],
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text(
          'Register Veterinarian',
          style: TextStyle(
            color: CareTheme.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field(_nameCtrl, 'Doctor Name (e.g., Dr. Sita Karki)'),
            _field(_clinicCtrl, 'Clinic Name'),
            _field(_specCtrl, 'Specialty'),
            _field(_addressCtrl, 'Clinic Location'),
            _field(_feeCtrl, 'Consultation Fee (₹)', isNumber: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CareTheme.terracotta,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveVet,
                child: const Text('Save Veterinarian'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: CareTheme.cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
