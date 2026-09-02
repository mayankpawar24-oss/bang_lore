import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { requested, approved, confirmed, rejected, cancelled, completed, scheduled, pending, missed }

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
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
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
    this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    this.createdAt,
    this.updatedAt,
  });

  String get appointmentId => id;
  int get duration => durationMinutes;

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
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
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
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointmentId': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientName': patientName,
      'specialty': specialty,
      'dateTime': dateTime.toIso8601String(),
      'duration': durationMinutes,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'notes': notes,
      'location': location,
      'requestedAt': requestedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: (json['id'] as String?) ?? (json['appointmentId'] as String?) ?? '',
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ?? DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? (json['duration'] as num?)?.toInt() ?? 30,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      notes: json['notes'] as String?,
      location: json['location'] as String?,
      requestedAt: json['requestedAt'] != null ? DateTime.tryParse(json['requestedAt'] as String) : null,
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'] as String) : null,
      rejectedAt: json['rejectedAt'] != null ? DateTime.tryParse(json['rejectedAt'] as String) : null,
    );
  }

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final docId = (data['appointmentId'] as String?) ?? doc.id;
    return Appointment(
      id: docId,
      patientId: data['patientId'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      doctorName: data['doctorName'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      specialty: data['specialty'] as String? ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? (data['duration'] as num?)?.toInt() ?? 30,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'pending'),
        orElse: () => AppointmentStatus.pending,
      ),
      notes: data['notes'] as String?,
      location: data['location'] as String?,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'appointmentId': id,
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientName': patientName,
      'specialty': specialty,
      'dateTime': Timestamp.fromDate(dateTime),
      'duration': durationMinutes,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'notes': notes,
      'location': location,
      'requestedAt': requestedAt != null ? Timestamp.fromDate(requestedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'requestedAt': requestedAt != null ? Timestamp.fromDate(requestedAt!) : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef AppointmentModel = Appointment;
