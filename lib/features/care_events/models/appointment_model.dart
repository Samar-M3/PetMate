// Holds id, petName, vetId, vetName, date, timeSlot,
//     type ("In-Clinic" or "Video Consult"), status ("Upcoming", "Completed",
// "Cancelled"), and vetNotes / nextVaccineDate.
class Appointment {
  final String id;
  final String petName;
  final String vetId;
  final String vetName;
  final String clinicName;
  final String date;
  final String timeSlot;
  final String reason;
  String status; // 'Upcoming', 'Completed', 'Cancelled'
  String? vetNotes;
  String? nextVaccineDue;

  Appointment({
    required this.id,
    required this.petName,
    required this.vetId,
    required this.vetName,
    required this.clinicName,
    required this.date,
    required this.timeSlot,
    required this.reason,
    this.status = 'Upcoming',
    this.vetNotes,
    this.nextVaccineDue,
  });
}
