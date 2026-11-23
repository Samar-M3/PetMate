import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme.dart';
import '../../models/vet_model.dart';
import '../../providers/care_events_provider.dart';
import '../../utils/care_format.dart';
import '../../widgets/care_ui.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  final Vet vet;
  const BookAppointmentScreen({super.key, required this.vet});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  static const int _daysAhead = 7;

  final _petController = TextEditingController();
  final _reasonController = TextEditingController();

  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  String? _selectedSlot;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final today = todayDate();
    _dates = [
      for (var i = 0; i < _daysAhead; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    _selectedDate = _dates.first;
    _selectedSlot = _firstBookableSlot();
  }

  @override
  void dispose() {
    _petController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// A slot is bookable unless it has already started today.
  bool _isBookable(String slot) {
    if (!isSameDay(_selectedDate, todayDate())) return true;
    final minutes = slotMinutes(slot);
    if (minutes == null) return true;
    final now = DateTime.now();
    return minutes > now.hour * 60 + now.minute;
  }

  String? _firstBookableSlot() {
    for (final s in widget.vet.availableSlots) {
      if (_isBookable(s)) return s;
    }
    return null;
  }

  Future<void> _confirmBooking() async {
    final pet = _petController.text.trim();
    if (pet.isEmpty) {
      showCareSnackBar(context, 'Please enter your pet\'s name.', isError: true);
      return;
    }
    final slot = _selectedSlot;
    if (slot == null) {
      showCareSnackBar(context, 'Please choose a time slot.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(appointmentsProvider.notifier).bookAppointment(
            petName: pet,
            vetId: widget.vet.id,
            date: formatCareDate(_selectedDate),
            timeSlot: slot,
            reason: _reasonController.text.trim().isEmpty
                ? 'General In-Clinic Checkup'
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      showCareSnackBar(context, 'Clinic appointment booked!');
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        showCareSnackBar(context, 'Booking failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vet = widget.vet;

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('Schedule Clinic Visit'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CareTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vet.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CareTheme.charcoal)),
                  Text(
                    vet.address.isEmpty
                        ? vet.clinicName
                        : '${vet.clinicName} (${vet.address})',
                    style: const TextStyle(color: CareTheme.mutedText),
                  ),
                  if (vet.fee > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                        'Consultation Fee: ${formatFee(vet.fee)} (Pay at Clinic)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: CareTheme.deepOlive)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Pet Name'),
            TextField(
              controller: _petController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('e.g., Toto'),
            ),
            const SizedBox(height: 20),
            _label('Select Date'),
            Wrap(
              spacing: 10,
              children: _dates.map((date) {
                return ChoiceChip(
                  label: Text('${weekdayShort(date)} • ${monthShort(date)} ${date.day}'),
                  selected: isSameDay(_selectedDate, date),
                  selectedColor: CareTheme.sageGreen,
                  onSelected: (_) => setState(() {
                    _selectedDate = date;
                    if (_selectedSlot == null || !_isBookable(_selectedSlot!)) {
                      _selectedSlot = _firstBookableSlot();
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _label('Available Time Slots'),
            if (vet.availableSlots.isEmpty)
              const Text('This clinic has no open slots right now.',
                  style: TextStyle(color: CareTheme.mutedText))
            else
              Wrap(
                spacing: 10,
                children: vet.availableSlots.map((slot) {
                  final bookable = _isBookable(slot);
                  final selected = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: selected,
                    selectedColor: CareTheme.terracotta,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : CareTheme.charcoal,
                    ),
                    onSelected:
                        bookable ? (_) => setState(() => _selectedSlot = slot) : null,
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            _label('Reason for Visit'),
            TextField(
              controller: _reasonController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              decoration:
                  _inputDecoration('e.g., Vaccination, routine checkup, skin allergy...'),
            ),
            const SizedBox(height: 20),
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
                onPressed: (_submitting || _selectedSlot == null)
                    ? null
                    : _confirmBooking,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: CareTheme.charcoal)),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: CareTheme.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
