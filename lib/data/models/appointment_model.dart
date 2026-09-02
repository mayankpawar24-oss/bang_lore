import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { requested, approved, confirmed, rejected, cancelled, completed, scheduled, pending }

class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String patientName;
  final String specialty;
  final DateTime dateTime;
  final int durationMinutes;
  final AppointmentStatus status;
  final String? notes;
  final String? location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.patientName,
    required this.specialty,
    required this.dateTime,
    required this.durationMinutes,
    required this.status,
    this.notes,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

  Appointment copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? doctorName,
    String? patientName,
    String? specialty,
    DateTime? dateTime,
    int? durationMinutes,
    AppointmentStatus? status,
    String? notes,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientName: patientName ?? this.patientName,
      specialty: specialty ?? this.specialty,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientName': patientName,
      'specialty': specialty,
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'status': status.name,
      'notes': notes,
      'location': location,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      patientName: json['patientName'] as String,
      specialty: json['specialty'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      durationMinutes: json['durationMinutes'] as int,
      status: AppointmentStatus.values.firstWhere((e) => e.name == json['status']),
      notes: json['notes'] as String?,
      location: json['location'] as String?,
    );
  }

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      doctorName: data['doctorName'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      specialty: data['specialty'] as String? ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'scheduled'),
        orElse: () => AppointmentStatus.scheduled,
      ),
      notes: data['notes'] as String?,
      location: data['location'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientName': patientName,
      'specialty': specialty,
      'dateTime': Timestamp.fromDate(dateTime),
      'durationMinutes': durationMinutes,
      'status': status.name,
      'notes': notes,
      'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef AppointmentModel = Appointment;
