class Appointment {
  final String id;
  final String petName;
  final String vetId;
  final String vetName;
  final String clinicName;
  final String date;
  final String timeSlot;
  final String reason;
  final String status;
  final String? type;
  final String? vetNotes;
  final String? nextVaccineDue;

  const Appointment({
    required this.id,
    required this.petName,
    required this.vetId,
    required this.vetName,
    required this.clinicName,
    required this.date,
    required this.timeSlot,
    required this.reason,
    required this.status,
    this.type,
    this.vetNotes,
    this.nextVaccineDue,
  });
}
