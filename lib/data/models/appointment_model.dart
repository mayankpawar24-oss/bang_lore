enum AppointmentStatus { scheduled, completed, cancelled, pending }

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
    );
  }
}

typedef AppointmentModel = Appointment;
