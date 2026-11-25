import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  PetEntity? _selectedPet;

  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  String? _selectedSlot;
  bool _submitting = false;
  String? _initialError;

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
    
    // Validate vet availability upfront
    _validateVetAvailability();
  }

  void _validateVetAvailability() {
    final vet = widget.vet;
    if (!vet.isVerified) {
      _initialError = 'This veterinarian is not verified and cannot accept appointments.';
    } else if (!vet.isAcceptingBookings) {
      _initialError = 'This veterinarian is not currently accepting bookings.';
    } else if (vet.availableSlots.isEmpty) {
      _initialError = 'This veterinarian has no available time slots configured.';
    }
  }

  @override
  void dispose() {
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

  List<PetEntity> _getUserPets() {
    final user = ref.read(authStateProvider).user;
    if (user == null) return [];
    return user.pets.where((p) => p.isActive).toList();
  }

  Future<void> _confirmBooking() async {
    if (_selectedPet == null) {
      showCareSnackBar(context, 'Please select a pet.', isError: true);
      return;
    }
    final slot = _selectedSlot;
    if (slot == null) {
      showCareSnackBar(context, 'Please choose a time slot.', isError: true);
      return;
    }

    // Additional client-side validation
    final vet = widget.vet;
    if (!vet.isVerified) {
      showCareSnackBar(context, 'This veterinarian is not verified.', isError: true);
      return;
    }
    if (!vet.isAcceptingBookings) {
      showCareSnackBar(context, 'This veterinarian is not accepting bookings.', isError: true);
      return;
    }
    if (!vet.availableSlots.contains(slot)) {
      showCareSnackBar(context, 'Selected time slot is no longer available.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(appointmentsProvider.notifier).bookAppointment(
            petName: _selectedPet!.name,
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
        // Provide more user-friendly error messages
        String errorMessage = e.toString();
        if (errorMessage.contains('Veterinarian not found')) {
          errorMessage = 'Veterinarian not found. Please try again.';
        } else if (errorMessage.contains('not verified')) {
          errorMessage = 'This veterinarian is not verified.';
        } else if (errorMessage.contains('not currently accepting bookings')) {
          errorMessage = 'This veterinarian is not currently accepting bookings.';
        } else if (errorMessage.contains('not available for this veterinarian')) {
          errorMessage = 'Selected time slot is not available for this veterinarian.';
        } else if (errorMessage.contains('already been booked')) {
          errorMessage = 'This time slot has already been booked. Please choose another.';
        } else if (errorMessage.contains('Pet not found')) {
          errorMessage = 'Pet not found. Please select a valid pet.';
        } else if (errorMessage.contains('401') || errorMessage.contains('session has expired')) {
          errorMessage = 'Your session has expired. Please sign in again.';
        } else if (errorMessage.contains('403') || errorMessage.contains('permission')) {
          errorMessage = 'You do not have permission to book this appointment.';
        } else if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring('Exception: '.length);
        }
        showCareSnackBar(context, 'Booking failed: $errorMessage', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vet = widget.vet;
    final userPets = _getUserPets();

    // Show error if vet is not available for booking
    if (_initialError != null) {
      return Scaffold(
        backgroundColor: CareTheme.background,
        appBar: careAppBar('Schedule Clinic Visit'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 64,
                  color: CareTheme.terracotta.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to Book',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: CareTheme.charcoal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _initialError!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: CareTheme.mutedText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CareTheme.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CareTheme.background,
      appBar: careAppBar('Schedule Clinic Visit'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
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
                  Text(
                    vet.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CareTheme.charcoal,
                    ),
                  ),
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
                        color: CareTheme.deepOlive,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Select Pet'),
            if (userPets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CareTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No registered pets found.',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: CareTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please add a pet from your profile before booking an appointment.',
                      style: TextStyle(color: CareTheme.mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/profile'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Pet'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CareTheme.terracotta,
                          side: const BorderSide(color: CareTheme.terracotta),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<PetEntity>(
                value: _selectedPet,
                decoration: _inputDecoration('Select your pet'),
                isExpanded: true,
                items: userPets.map((pet) {
                  final imageUrl = pet.effectiveImageUrl;
                  return DropdownMenuItem<PetEntity>(
                    value: pet,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: CareTheme.sageGreen,
                          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                              ? NetworkImage(imageUrl)
                              : null,
                          child: (imageUrl == null || imageUrl.isEmpty)
                              ? const Icon(Icons.pets, size: 18, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pet.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: CareTheme.charcoal),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (pet.animalType != null || pet.breed != null)
                                Text(
                                  '${pet.animalType ?? ''}${pet.animalType != null && pet.breed != null ? ' • ' : ''}${pet.breed ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12, color: CareTheme.mutedText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (pet) => setState(() => _selectedPet = pet),
                validator: (value) => value == null ? 'Please select a pet' : null,
              ),
            const SizedBox(height: 20),
            _label('Select Date'),
            Wrap(
              spacing: 10,
              children: _dates.map((date) {
                return ChoiceChip(
                  label: Text(
                    '${weekdayShort(date)} • ${monthShort(date)} ${date.day}',
                  ),
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
              const Text(
                'This clinic has no open slots right now.',
                style: TextStyle(color: CareTheme.mutedText),
              )
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
                    onSelected: bookable
                        ? (_) => setState(() => _selectedSlot = slot)
                        : null,
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            _label('Reason for Visit'),
            TextField(
              controller: _reasonController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              decoration: _inputDecoration(
                'e.g., Vaccination, routine checkup, skin allergy...',
              ),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (_submitting || _selectedSlot == null)
                    ? null
                    : _confirmBooking,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Confirm Clinic Appointment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: CareTheme.charcoal,
      ),
    ),
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
