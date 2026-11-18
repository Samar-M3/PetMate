import 'vet_model.dart';
import 'appointment_model.dart';
import 'event_model.dart';

class MockCareData {
  static List<Vet> vets = [
    Vet(
      id: 'v1',
      name: 'Dr. Aarav Sharma',
      clinicName: 'Paws & Claws Veterinary Clinic',
      specialty: 'General & Preventive Care',
      address: 'Jhamsikhel, Lalitpur',
      rating: 4.9,
      fee: 499,
      availableSlots: ['09:30 AM', '11:00 AM', '02:30 PM', '04:45 PM'],
    ),
    Vet(
      id: 'v2',
      name: 'Dr. Priya Gurung',
      clinicName: 'Himalayan Pet Wellness Center',
      specialty: 'Surgery & Orthopedics',
      address: 'Lazimpat, Kathmandu',
      rating: 4.8,
      fee: 650,
      availableSlots: ['10:00 AM', '01:00 PM', '03:30 PM'],
    ),
    Vet(
      id: 'v3',
      name: 'Dr. Rohan Thapa',
      clinicName: 'Happy Tails Animal Hospital',
      specialty: 'Dermatology & Nutrition',
      address: 'Bhaisepati, Lalitpur',
      rating: 4.7,
      fee: 450,
      availableSlots: ['10:30 AM', '12:15 PM', '05:00 PM'],
    ),
  ];

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

  static List<PetEvent> events = [
    PetEvent(
      id: 'e1',
      title: 'Paws in the Park',
      category: 'MEETUP',
      dayName: 'SUN',
      dayNum: '22',
      fullDate: 'Nov 22, 2026',
      time: '08:30 AM - 11:00 AM',
      location: 'Central Zoo Park Lawn, Jawalakhel',
      description:
      'Morning off-leash socialization meetup for friendly dogs and pet parents. Complimentary treats and hydration bowls provided.',
      attendeeCount: 46,
    ),
    PetEvent(
      id: 'e2',
      title: 'Weekend Agility & Trick Trial',
      category: 'AGILITY',
      dayName: 'SAT',
      dayNum: '28',
      fullDate: 'Nov 28, 2026',
      time: '03:00 PM - 05:30 PM',
      location: 'Greenfield Pet Arena, Sanepa',
      description:
      'Beginner-friendly obstacle course run guided by certified trainers. Open to all breeds and ages.',
      attendeeCount: 29,
    ),
  ];
}
