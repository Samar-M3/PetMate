import 'appointment_model.dart';
import 'event_model.dart';
import 'vet_model.dart';

class MockCareData {
  static List<Vet> vets = [];

  static List<Appointment> appointments = [
    Appointment(
      id: 'a1',
      petName: 'Toto',
      vetId: 'v1',
      vetName: 'Dr. Aarav Sharma',
      clinicName: 'Paws & Claws Veterinary Clinic',
      date: 'Nov 22, 2026',
      timeSlot: '11:00 AM',
      reason: 'Annual DHPP Booster & Checkup',
      status: 'Upcoming',
    ),
    Appointment(
      id: 'a0',
      petName: 'Toto',
      vetId: 'v1',
      vetName: 'Dr. Aarav Sharma',
      clinicName: 'Paws & Claws Veterinary Clinic',
      date: 'Sep 14, 2026',
      timeSlot: '10:00 AM',
      reason: 'Rabies Vaccination',
      status: 'Completed',
      vetNotes: 'Healthy weight (14.2 kg). Rabies booster administered.',
      nextVaccineDue: 'Dec 28, 2026',
    ),
  ];

  static List<PetEvent> events = [];
}
