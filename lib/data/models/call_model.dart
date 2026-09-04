import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String channelId;
  final String status; // 'ringing', 'accepted', 'rejected', 'ended'
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  final List<String> participants;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerRole,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    required this.channelId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.endedAt,
    this.participants = const [],
    this.offer,
    this.answer,
  });

  bool get isRinging => status == 'ringing';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isEnded => status == 'ended';
  bool get isActive => isRinging || isAccepted;

  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    final acceptedTs = data['acceptedAt'] as Timestamp?;
    final endedTs = data['endedAt'] as Timestamp?;
    final callerId = data['callerId'] as String? ?? '';
    final receiverId = data['receiverId'] as String? ?? '';

    List<String> parts = [];
    if (data['participants'] is List) {
      parts = (data['participants'] as List).map((e) => e.toString()).toList();
    } else {
      parts = [callerId, receiverId]..sort();
    }

    return CallModel(
      id: doc.id,
      callerId: callerId,
      callerName: data['callerName'] as String? ?? 'Caller',
      callerRole: data['callerRole'] as String? ?? 'patient',
      callerPhoto: data['callerPhoto'] as String?,
      receiverId: receiverId,
      receiverName: data['receiverName'] as String? ?? 'Receiver',
      receiverRole: data['receiverRole'] as String? ?? 'doctor',
      channelId: data['channelId'] as String? ?? 'channel_${doc.id}',
      status: data['status'] as String? ?? 'ringing',
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      acceptedAt: acceptedTs?.toDate(),
      endedAt: endedTs?.toDate(),
      participants: parts,
      offer: data['offer'] as Map<String, dynamic>?,
      answer: data['answer'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final parts = participants.isNotEmpty ? participants : ([callerId, receiverId]..sort());
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole,
      if (callerPhoto != null) 'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
      'channelId': channelId,
      'status': status,
      'participants': parts,
      if (offer != null) 'offer': offer,
      if (answer != null) 'answer': answer,
      'createdAt': Timestamp.fromDate(createdAt),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerRole,
    String? callerPhoto,
    String? receiverId,
    String? receiverName,
    String? receiverRole,
    String? channelId,
    String? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
    List<String>? participants,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerRole: callerRole ?? this.callerRole,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverRole: receiverRole ?? this.receiverRole,
      channelId: channelId ?? this.channelId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
      participants: participants ?? this.participants,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
    );
  }
}
