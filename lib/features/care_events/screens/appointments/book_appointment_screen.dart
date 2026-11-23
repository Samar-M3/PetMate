import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_theme.dart';
import '../../models/vet_model.dart';
import '../../providers/care_events_provider.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  final Vet vet;
  const BookAppointmentScreen({super.key, required this.vet});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  String _selectedPet = 'Toto';
  String _selectedDate = 'Nov 24, 2026';
  String? _selectedSlot;
  bool _submitting = false;
  final TextEditingController _reasonController = TextEditingController();

  final List<String> _dates = ['Nov 24, 2026', 'Nov 25, 2026', 'Nov 26, 2026'];

  @override
  void initState() {
    super.initState();
    if (widget.vet.availableSlots.isNotEmpty) {
      _selectedSlot = widget.vet.availableSlots.first;
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(appointmentsProvider.notifier).bookAppointment(
        petName: _selectedPet,
        vetId: widget.vet.id,
        date: _selectedDate,
        timeSlot: _selectedSlot!,
        reason: _reasonController.text.trim().isEmpty
            ? 'General In-Clinic Checkup'
            : _reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinic appointment booked!')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: AppBar(
        backgroundColor: CareTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: CareTheme.charcoal),
        title: const Text('Schedule Clinic Visit',
            style: TextStyle(
                color: CareTheme.charcoal, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CareTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.vet.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CareTheme.charcoal)),
                  Text('${widget.vet.clinicName} (${widget.vet.address})',
                      style: const TextStyle(color: CareTheme.mutedText)),
                  const SizedBox(height: 6),
                  Text('Consultation Fee: ₹${widget.vet.fee} (Pay at Clinic)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CareTheme.deepOlive)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Select Pet',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: ['Toto', 'Bella'].map((pet) {
                return ChoiceChip(
                  label: Text(pet),
                  selected: _selectedPet == pet,
                  selectedColor: CareTheme.sageGreen,
                  onSelected: (_) => setState(() => _selectedPet = pet),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Select Date',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _dates.map((date) {
                return ChoiceChip(
                  label: Text(date),
                  selected: _selectedDate == date,
                  selectedColor: CareTheme.sageGreen,
                  onSelected: (_) => setState(() => _selectedDate = date),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Available Time Slots',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: widget.vet.availableSlots.map((slot) {
                return ChoiceChip(
                  label: Text(slot),
                  selected: _selectedSlot == slot,
                  selectedColor: CareTheme.terracotta,
                  labelStyle: TextStyle(
                    color: _selectedSlot == slot
                        ? Colors.white
                        : CareTheme.charcoal,
                  ),
                  onSelected: (_) => setState(() => _selectedSlot = slot),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Reason for Visit',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Vaccination, routine checkup, skin allergy...',
                filled: true,
                fillColor: CareTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CareTheme.terracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submitting ? null : _confirmBooking,
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Clinic Appointment',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
