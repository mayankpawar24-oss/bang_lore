import '../models/patient_model.dart';
import '../models/doctor_model.dart';
import '../models/family_member_model.dart';
import '../models/appointment_model.dart';
import '../models/medication_model.dart';
import '../models/reminder_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class MockData {
  // Convenience aliases
  static const margaretChen = UserModel(
    id: 'p_margaret_01',
    name: 'Margaret Chen',
    email: 'margaret@demo.com',
    role: UserRole.patient,
  );

  static const drAishaPatel = UserModel(
    id: 'd_aisha_01',
    name: 'Dr. Aisha Patel',
    email: 'aisha@demo.com',
    role: UserRole.doctor,
  );

  static final Patient currentPatient = Patient(
    id: 'p_margaret_01',
    name: 'Margaret Chen',
    age: 72,
    condition: 'Heart Failure',
    status: 'stable',
    medicationAdherence: 87.0,
    avatarUrl: 'https://i.pravatar.cc/150?u=margaret',
    connectedDoctorId: 'd_aisha_01',
    vitals: {
      'hr': 74,
      'spo2': 97,
      'weight': 68.4,
    },
    conditions: ['Heart Failure', 'Hypertension'],
    isAuthorized: true,
  );

  static final List<Patient> patients = [
    currentPatient,
    Patient(
      id: 'p_john_02',
      name: 'John Smith',
      age: 58,
      condition: 'Type 2 Diabetes',
      status: 'attention',
      medicationAdherence: 64.0,
      avatarUrl: 'https://i.pravatar.cc/150?u=john',
      connectedDoctorId: 'd_aisha_01',
      vitals: {
        'hr': 82,
        'spo2': 96,
        'weight': 89.2,
      },
      conditions: ['Type 2 Diabetes', 'Obesity'],
      isAuthorized: false,
    ),
    Patient(
      id: 'p_emily_03',
      name: 'Emily Rodriguez',
      age: 45,
      condition: 'Hypertension',
      status: 'stable',
      medicationAdherence: 92.0,
      avatarUrl: 'https://i.pravatar.cc/150?u=emily',
      connectedDoctorId: 'd_aisha_01',
      vitals: {
        'hr': 68,
        'spo2': 98,
        'weight': 62.1,
      },
      conditions: ['Hypertension'],
      isAuthorized: true,
    ),
    Patient(
      id: 'p_raj_04',
      name: 'Raj Kapoor',
      age: 67,
      condition: 'COPD',
      status: 'critical',
      medicationAdherence: 45.0,
      avatarUrl: 'https://i.pravatar.cc/150?u=raj',
      connectedDoctorId: null,
      vitals: {
        'hr': 92,
        'spo2': 91,
        'weight': 72.8,
      },
      conditions: ['COPD', 'Chronic Bronchitis'],
      isAuthorized: false,
    ),
  ];

  static final List<Doctor> doctors = [
    const Doctor(
      id: 'd_aisha_01',
      name: 'Dr. Aisha Patel',
      specialty: 'Cardiology',
      hospital: 'City Heart Center',
      rating: 4.9,
      distance: 1.2,
      avatarUrl: 'https://i.pravatar.cc/150?u=aisha',
      phone: '+1234567890',
      about: 'Experienced Cardiologist with 15 years of practice in interventional cardiology and heart failure management.',
      availableDays: ['Monday', 'Wednesday', 'Friday'],
      isAvailable: true,
    ),
    const Doctor(
      id: 'd_james_02',
      name: 'Dr. James Wilson',
      specialty: 'Neurology',
      hospital: 'Metro General Hospital',
      rating: 4.8,
      distance: 3.5,
      avatarUrl: 'https://i.pravatar.cc/150?u=james',
      phone: '+1234567891',
      about: 'Specializes in neurodegenerative diseases and stroke management.',
      availableDays: ['Tuesday', 'Thursday'],
      isAvailable: true,
    ),
    const Doctor(
      id: 'd_sarah_03',
      name: 'Dr. Sarah Kim',
      specialty: 'Endocrinology',
      hospital: 'Wellness Clinic',
      rating: 4.7,
      distance: 2.1,
      avatarUrl: 'https://i.pravatar.cc/150?u=sarahkim',
      phone: '+1234567892',
      about: 'Expert in diabetes management and thyroid disorders.',
      availableDays: ['Monday', 'Tuesday', 'Wednesday'],
      isAvailable: true,
    ),
    const Doctor(
      id: 'd_michael_04',
      name: 'Dr. Michael Brown',
      specialty: 'General Practice',
      hospital: 'Family Health Care',
      rating: 4.6,
      distance: 0.8,
      avatarUrl: 'https://i.pravatar.cc/150?u=michael',
      phone: '+1234567893',
      about: 'Compassionate family doctor with 20 years of experience.',
      availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      isAvailable: true,
    ),
    const Doctor(
      id: 'd_priya_05',
      name: 'Dr. Priya Sharma',
      specialty: 'Pulmonology',
      hospital: 'Lung Care Institute',
      rating: 4.9,
      distance: 4.0,
      avatarUrl: 'https://i.pravatar.cc/150?u=priya',
      phone: '+1234567894',
      about: 'Specialist in respiratory disorders and sleep medicine.',
      availableDays: ['Wednesday', 'Thursday', 'Friday'],
      isAvailable: false,
    ),
  ];

  static final List<FamilyMember> familyMembers = [
    FamilyMember(
      id: 'fm_wei_00',
      name: 'Grandmother Wei',
      relationship: 'Grandmother',
      generation: 0,
      knownConditions: ['Hypertension', 'Type 2 Diabetes'],
      familyHistory: ['Stroke'],
      careNeeds: 'Regular blood pressure monitoring',
      careTasks: [
        CareTask(id: 'ct_w1', title: 'Blood pressure check', status: CareTaskStatus.active, assignedTo: 'Margaret'),
        CareTask(id: 'ct_w2', title: 'Medication refill', status: CareTaskStatus.done, assignedTo: 'David'),
      ],
      hydration: HydrationStatus.done,
      walking: WalkingStatus.needed,
      medication: MedicationStatus.done,
    ),
    FamilyMember(
      id: 'fm_david_01',
      name: 'David Chen',
      relationship: 'Father',
      generation: 1,
      knownConditions: ['Coronary Artery Disease'],
      familyHistory: ['Hypertension', 'Type 2 Diabetes'],
      careNeeds: 'Diet monitoring',
      careTasks: [
        CareTask(id: 'ct_d1', title: 'Cardiology follow-up', status: CareTaskStatus.todo, assignedTo: 'Margaret'),
      ],
      hydration: HydrationStatus.needed,
      walking: WalkingStatus.done,
      medication: MedicationStatus.active,
    ),
    const FamilyMember(
      id: 'fm_lily_02',
      name: 'Aunt Lily',
      relationship: 'Aunt',
      generation: 1,
      knownConditions: [],
      familyHistory: ['Hypertension'],
      careTasks: [],
      hydration: HydrationStatus.done,
      walking: WalkingStatus.done,
      medication: MedicationStatus.done,
    ),
    FamilyMember(
      id: 'fm_margaret_03',
      name: 'Margaret (You)',
      relationship: 'Self',
      generation: 2,
      knownConditions: ['Heart Failure', 'Hypertension'],
      familyHistory: ['Coronary Artery Disease', 'Type 2 Diabetes'],
      careTasks: [
        CareTask(id: 'ct_m1', title: 'Evening medication', status: CareTaskStatus.todo, assignedTo: 'Self'),
        CareTask(id: 'ct_m2', title: 'Walk 20 minutes', status: CareTaskStatus.active, assignedTo: 'Self'),
      ],
      hydration: HydrationStatus.needed,
      walking: WalkingStatus.active,
      medication: MedicationStatus.needed,
    ),
    FamilyMember(
      id: 'fm_sarah_04',
      name: 'Sarah',
      relationship: 'Daughter',
      generation: 3,
      knownConditions: [],
      familyHistory: ['Heart Failure', 'Coronary Artery Disease'],
      careTasks: [
        CareTask(id: 'ct_s1', title: 'Remind Mom to walk at 6 PM', status: CareTaskStatus.todo, assignedTo: 'Sarah'),
        CareTask(id: 'ct_s2', title: 'Check Mom\'s blood pressure', status: CareTaskStatus.active, assignedTo: 'Sarah'),
      ],
      hydration: HydrationStatus.done,
      walking: WalkingStatus.active,
      medication: MedicationStatus.done,
    ),
    FamilyMember(
      id: 'fm_rahul_05',
      name: 'Rahul',
      relationship: 'Son',
      generation: 3,
      knownConditions: [],
      familyHistory: ['Heart Failure', 'Coronary Artery Disease'],
      careTasks: [
        CareTask(id: 'ct_r1', title: 'Pick up prescriptions', status: CareTaskStatus.active, assignedTo: 'Rahul'),
        CareTask(id: 'ct_r2', title: 'Check Mom\'s medication', status: CareTaskStatus.todo, assignedTo: 'Rahul'),
      ],
      hydration: HydrationStatus.needed,
      walking: WalkingStatus.active,
      medication: MedicationStatus.done,
    ),
  ];

  static final List<Appointment> appointments = [
    Appointment(
      id: 'app_01',
      patientId: 'p_margaret_01',
      doctorId: 'd_aisha_01',
      doctorName: 'Dr. Aisha Patel',
      patientName: 'Margaret Chen',
      specialty: 'Cardiology',
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      durationMinutes: 30,
      status: AppointmentStatus.scheduled,
      notes: 'Routine checkup for heart failure management.',
    ),
    Appointment(
      id: 'app_02',
      patientId: 'p_margaret_01',
      doctorId: 'd_james_02',
      doctorName: 'Dr. James Wilson',
      patientName: 'Margaret Chen',
      specialty: 'Neurology',
      dateTime: DateTime.now().subtract(const Duration(days: 14)),
      durationMinutes: 45,
      status: AppointmentStatus.completed,
      notes: 'Completed neurological assessment.',
    ),
    Appointment(
      id: 'app_03',
      patientId: 'p_margaret_01',
      doctorId: 'd_sarah_03',
      doctorName: 'Dr. Sarah Kim',
      patientName: 'Margaret Chen',
      specialty: 'Endocrinology',
      dateTime: DateTime.now().add(const Duration(days: 5)),
      durationMinutes: 30,
      status: AppointmentStatus.scheduled,
    ),
  ];

  static final List<Medication> medications = [
    Medication(
      id: 'med_01',
      name: 'Furosemide',
      dosage: '40mg',
      time: '8:00 AM',
      isTaken: true,
      date: DateTime.now(),
    ),
    Medication(
      id: 'med_02',
      name: 'Lisinopril',
      dosage: '10mg',
      time: '6:00 PM',
      isTaken: false,
      date: DateTime.now(),
    ),
    Medication(
      id: 'med_03',
      name: 'Metoprolol',
      dosage: '25mg',
      time: '8:00 PM',
      isTaken: false,
      date: DateTime.now(),
    ),
  ];

  static final List<Reminder> reminders = [
    Reminder(
      id: 'rem_01',
      title: 'Take Lisinopril',
      description: 'Evening dose of Lisinopril 10mg',
      type: ReminderType.medicine,
      dateTime: DateTime.now().add(const Duration(hours: 2)),
      isCompleted: false,
    ),
    Reminder(
      id: 'rem_02',
      title: 'Drink water',
      description: 'Stay hydrated - drink 1 glass of water',
      type: ReminderType.hydration,
      dateTime: DateTime.now().add(const Duration(minutes: 30)),
      isCompleted: false,
    ),
    Reminder(
      id: 'rem_03',
      title: 'Evening walk',
      description: '20 minute walk around the block',
      type: ReminderType.walking,
      dateTime: DateTime.now().add(const Duration(hours: 4)),
      isCompleted: false,
      assignedBy: 'Sarah',
    ),
    Reminder(
      id: 'rem_04',
      title: 'Cardiology appointment',
      description: 'With Dr. Aisha Patel tomorrow',
      type: ReminderType.appointment,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      isCompleted: false,
    ),
  ];

  static final List<NotificationModel> notifications = [
    NotificationModel(
      id: 'notif_01',
      title: 'Upcoming Appointment',
      message: 'You have an appointment with Dr. Aisha Patel tomorrow at 10:30 AM.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.appointment,
      isRead: false,
    ),
    NotificationModel(
      id: 'notif_02',
      title: 'Medication Reminder',
      message: 'Did you take your morning Furosemide?',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      type: NotificationType.medication,
      isRead: true,
    ),
    NotificationModel(
      id: 'notif_03',
      title: 'AI Health Insight',
      message: 'Your medication adherence has improved this week. Keep it up!',
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      type: NotificationType.general,
      isRead: false,
    ),
  ];
}
