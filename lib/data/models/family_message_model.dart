import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMessageModel {
  final String id;
  final String patientId;
  final String? familyId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String? senderAvatar;
  final String content;
  final DateTime timestamp;
  final String type; // 'text', 'report', 'image', 'alert'
  final String? reportId;
  final String? reportTitle;
  final String? reportCategory;
  final String? reportUrl;
  final DateTime? reportDate;
  final List<String> readBy;

  String get messageId => id;
  String? get senderPhoto => senderAvatar;
  String get text => content;
  DateTime get createdAt => timestamp;

  const FamilyMessageModel({
    required this.id,
    required this.patientId,
    this.familyId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderAvatar,
    required this.content,
    required this.timestamp,
    this.type = 'text',
    this.reportId,
    this.reportTitle,
    this.reportCategory,
    this.reportUrl,
    this.reportDate,
    this.readBy = const [],
  });

  FamilyMessageModel copyWith({
    String? id,
    String? patientId,
    String? familyId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderAvatar,
    String? content,
    DateTime? timestamp,
    String? type,
    String? reportId,
    String? reportTitle,
    String? reportCategory,
    String? reportUrl,
    DateTime? reportDate,
    List<String>? readBy,
  }) {
    return FamilyMessageModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      familyId: familyId ?? this.familyId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      reportId: reportId ?? this.reportId,
      reportTitle: reportTitle ?? this.reportTitle,
      reportCategory: reportCategory ?? this.reportCategory,
      reportUrl: reportUrl ?? this.reportUrl,
      reportDate: reportDate ?? this.reportDate,
      readBy: readBy ?? this.readBy,
    );
  }

  factory FamilyMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawText = data['text'] as String? ?? data['content'] as String? ?? '';
    final rawTimestamp = (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['timestamp'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final rawAvatar = data['senderPhoto'] as String? ?? data['senderAvatar'] as String?;

    return FamilyMessageModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      familyId: data['familyId'] as String?,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Family Member',
      senderRole: data['senderRole'] as String? ?? 'member',
      senderAvatar: rawAvatar,
      content: rawText,
      timestamp: rawTimestamp,
      type: data['type'] as String? ?? 'text',
      reportId: data['reportId'] as String?,
      reportTitle: data['reportTitle'] as String?,
      reportCategory: data['reportCategory'] as String?,
      reportUrl: data['reportUrl'] as String?,
      reportDate: (data['reportDate'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': id,
      'patientId': patientId,
      'familyId': familyId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'senderAvatar': senderAvatar,
      'senderPhoto': senderAvatar,
      'content': content,
      'text': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      'type': type,
      'reportId': reportId,
      'reportTitle': reportTitle,
      'reportCategory': reportCategory,
      'reportUrl': reportUrl,
      'reportDate': reportDate != null ? Timestamp.fromDate(reportDate!) : null,
      'readBy': readBy,
    };
  }
}
