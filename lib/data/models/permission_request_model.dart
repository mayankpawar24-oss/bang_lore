enum PermissionStatus { pending, approved, denied }

class PermissionRequest {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final PermissionStatus status;
  final DateTime requestedAt;

  const PermissionRequest({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.requestedAt,
  });

  PermissionRequest copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    String? patientId,
    String? patientName,
    PermissionStatus? status,
    DateTime? requestedAt,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
    };
  }

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json['id'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      patientId: json['patientId'] as String,
      patientName: json['patientName'] as String,
      status: PermissionStatus.values.firstWhere((e) => e.name == json['status']),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
    );
  }
}

typedef PermissionRequestModel = PermissionRequest;
