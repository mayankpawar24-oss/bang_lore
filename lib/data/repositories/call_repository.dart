import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class CallRepository {
  Future<CallModel> startCall({
    required String callerId,
    required String callerName,
    required String callerRole,
    String? callerPhoto,
    required String receiverId,
    required String receiverName,
    required String receiverRole,
  });

  Stream<CallModel?> streamCall(String callId);
  Stream<CallModel?> streamIncomingCalls(String userId);

  Future<void> acceptCall(String callId);
  Future<void> rejectCall(String callId);
  Future<void> endCall(String callId);

  Future<void> setOffer(String callId, Map<String, dynamic> offer);
  Future<void> setAnswer(String callId, Map<String, dynamic> answer);
  Future<void> addCallerCandidate(String callId, Map<String, dynamic> candidate);
  Future<void> addReceiverCandidate(String callId, Map<String, dynamic> candidate);
  Stream<List<Map<String, dynamic>>> streamCallerCandidates(String callId);
  Stream<List<Map<String, dynamic>>> streamReceiverCandidates(String callId);
}

class FirebaseCallRepository implements CallRepository {
  final FirebaseFirestore? _db;
  final ActivityLogService? _activityLogService;

  FirebaseCallRepository({FirebaseFirestore? db, ActivityLogService? activityLogService})
      : _db = db,
        _activityLogService = activityLogService;

  @override
  Future<CallModel> startCall({
    required String callerId,
    required String callerName,
    required String callerRole,
    String? callerPhoto,
    required String receiverId,
    required String receiverName,
    required String receiverRole,
  }) async {
    final db = _db ?? FirebaseFirestore.instance;
    final docRef = db.collection('calls').doc();
    final channelId = 'call_${docRef.id}';
    final now = DateTime.now();

    final call = CallModel(
      id: docRef.id,
      callerId: callerId,
      callerName: callerName,
      callerRole: callerRole,
      callerPhoto: callerPhoto,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverRole: receiverRole,
      channelId: channelId,
      status: 'ringing',
      createdAt: now,
      participants: [callerId, receiverId]..sort(),
    );

    await docRef.set(call.toFirestore());
    dev.log('[CALL] Started call ${docRef.id} channel $channelId from $callerName to $receiverName', name: 'CallRepository');

    try {
      final patientId = callerRole == 'patient' ? callerId : receiverId;
      await _activityLogService?.logEvent(
        patientId: patientId,
        eventType: ActivityEventType.chatStarted,
        title: 'Video Call Initiated',
        description: '$callerName initiated a secure video call consultation with $receiverName.',
        actorUid: callerId,
        actorRole: callerRole,
        metadata: {
          'callId': docRef.id,
          'channelId': channelId,
          'callerId': callerId,
          'receiverId': receiverId,
        },
      );
    } catch (_) {}

    return call;
  }

  @override
  Stream<CallModel?> streamCall(String callId) {
    if (callId.isEmpty) return Stream.value(null);
    final db = _db ?? FirebaseFirestore.instance;

    return db.collection('calls').doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CallModel.fromFirestore(doc);
    });
  }

  @override
  Stream<CallModel?> streamIncomingCalls(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    final db = _db ?? FirebaseFirestore.instance;

    return db
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return CallModel.fromFirestore(snap.docs.first);
        });
  }

  @override
  Future<void> acceptCall(String callId) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    dev.log('[CALL] Accepted call $callId', name: 'CallRepository');
  }

  @override
  Future<void> rejectCall(String callId) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).update({
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    dev.log('[CALL] Rejected call $callId', name: 'CallRepository');
  }

  @override
  Future<void> endCall(String callId) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    dev.log('[CALL] Ended call $callId', name: 'CallRepository');
  }

  @override
  Future<void> setOffer(String callId, Map<String, dynamic> offer) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).update({
      'offer': offer,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setAnswer(String callId, Map<String, dynamic> answer) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).update({
      'answer': answer,
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addCallerCandidate(String callId, Map<String, dynamic> candidate) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).collection('callerCandidates').add({
      ...candidate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addReceiverCandidate(String callId, Map<String, dynamic> candidate) async {
    if (callId.isEmpty) return;
    final db = _db ?? FirebaseFirestore.instance;
    await db.collection('calls').doc(callId).collection('receiverCandidates').add({
      ...candidate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> streamCallerCandidates(String callId) {
    if (callId.isEmpty) return Stream.value([]);
    final db = _db ?? FirebaseFirestore.instance;
    return db.collection('calls').doc(callId).collection('callerCandidates').snapshots().map(
      (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> streamReceiverCandidates(String callId) {
    if (callId.isEmpty) return Stream.value([]);
    final db = _db ?? FirebaseFirestore.instance;
    return db.collection('calls').doc(callId).collection('receiverCandidates').snapshots().map(
      (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }
}
