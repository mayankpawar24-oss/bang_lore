import 'dart:developer' as dev;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_relationship_model.dart';
import '../models/activity_log_model.dart';
import 'activity_log_service.dart';

class ResolvedTelegramTarget {
  final String? chatId;
  final bool isLinked;
  final String? username;
  final String patientName;

  const ResolvedTelegramTarget({
    this.chatId,
    required this.isLinked,
    this.username,
    required this.patientName,
  });
}

class PatientResolutionService {
  final FirebaseFirestore? _db;
  final ActivityLogService? _activityLogService;

  PatientResolutionService({
    FirebaseFirestore? db,
    ActivityLogService? activityLogService,
  })  : _db = db,
        _activityLogService = activityLogService;

  /// Resolves the patient's primary profile from 'patients' or 'users'
  Future<Map<String, dynamic>?> resolvePatient(String patientId) async {
    final db = _db;
    if (patientId.isEmpty || db == null) return null;

    try {
      final pDoc = await db.collection('patients').doc(patientId).get();
      if (pDoc.exists && pDoc.data() != null) {
        final data = pDoc.data()!;
        return {
          'id': patientId,
          'uid': patientId,
          'name': data['name'] as String? ?? 'Patient',
          'phone': (data['phone'] ?? data['phoneNumber']) as String? ?? '',
          'phoneNumber': (data['phone'] ?? data['phoneNumber']) as String? ?? '',
          'abhaNumber': (data['abhaNumber'] ?? data['abhaId']) as String? ?? '',
          'abhaId': (data['abhaNumber'] ?? data['abhaId']) as String? ?? '',
          'age': data['age'] as int? ?? 35,
          'avatar': data['avatar'] as String? ?? data['photoUrl'] as String?,
          'photoUrl': data['avatar'] as String? ?? data['photoUrl'] as String?,
          'telegramChatId': data['telegramChatId'] as String?,
          'telegramLinked': data['telegramLinked'] == true || data['telegramConnected'] == true,
          'telegramUsername': data['telegramUsername'] as String?,
          'condition': data['condition'] as String? ?? 'General Care',
          'status': data['status'] as String? ?? 'stable',
        };
      }

      final uDoc = await db.collection('users').doc(patientId).get();
      if (uDoc.exists && uDoc.data() != null) {
        final data = uDoc.data()!;
        return {
          'id': patientId,
          'uid': patientId,
          'name': data['name'] as String? ?? 'Patient',
          'phone': (data['phone'] ?? data['phoneNumber']) as String? ?? '',
          'phoneNumber': (data['phone'] ?? data['phoneNumber']) as String? ?? '',
          'abhaNumber': (data['abhaNumber'] ?? data['abhaId']) as String? ?? '',
          'abhaId': (data['abhaNumber'] ?? data['abhaId']) as String? ?? '',
          'age': data['age'] as int? ?? 35,
          'avatar': data['photoUrl'] as String? ?? data['avatar'] as String?,
          'photoUrl': data['photoUrl'] as String? ?? data['avatar'] as String?,
          'telegramChatId': data['telegramChatId'] as String?,
          'telegramLinked': data['telegramLinked'] == true || data['telegramConnected'] == true,
          'telegramUsername': data['telegramUsername'] as String?,
          'condition': 'General Care',
          'status': 'stable',
        };
      }
    } catch (e) {
      dev.log('[PATIENT_RESOLUTION] Failed to resolve patient $patientId: $e', name: 'PatientResolutionService');
    }
    return null;
  }

  /// Resolves the Telegram chat ID and verifies linking for a target patient
  Future<ResolvedTelegramTarget> resolveTelegramChat(String patientId) async {
    final profile = await resolvePatient(patientId);
    if (profile == null) {
      return const ResolvedTelegramTarget(
        chatId: null,
        isLinked: false,
        patientName: 'Unknown Patient',
      );
    }

    final chatId = profile['telegramChatId'] as String?;
    final isLinked = profile['telegramLinked'] == true;
    final username = profile['telegramUsername'] as String?;
    final patientName = profile['name'] as String? ?? 'Patient';

    return ResolvedTelegramTarget(
      chatId: (chatId != null && chatId.isNotEmpty && isLinked) ? chatId : null,
      isLinked: isLinked && chatId != null && chatId.isNotEmpty,
      username: username,
      patientName: patientName,
    );
  }

  /// Finds an existing registered patient by ABHA ID, Phone number, or QR Code.
  /// Returns null if no account exists (never fabricates fake profiles).
  Future<Map<String, dynamic>?> findPatientByQuery({
    String? abha,
    String? phone,
    String? qrCode,
  }) async {
    final db = _db;
    if (db == null) return null;

    // 1. Search by QR code (can be direct patient UID or continuum:// URI)
    if (qrCode != null && qrCode.trim().isNotEmpty) {
      String cleanQr = qrCode.trim();
      if (cleanQr.contains('continuum://patient/')) {
        final uri = Uri.tryParse(cleanQr);
        if (uri != null && uri.pathSegments.length >= 2) {
          cleanQr = uri.pathSegments[1];
        }
      }
      final direct = await resolvePatient(cleanQr);
      if (direct != null) return direct;
    }

    // 2. Search by ABHA Number
    if (abha != null && abha.trim().isNotEmpty) {
      final cleanAbha = abha.trim();
      try {
        final pSnap = await db.collection('patients').where('abhaNumber', isEqualTo: cleanAbha).limit(1).get();
        if (pSnap.docs.isNotEmpty) return await resolvePatient(pSnap.docs.first.id);

        final pSnapId = await db.collection('patients').where('abhaId', isEqualTo: cleanAbha).limit(1).get();
        if (pSnapId.docs.isNotEmpty) return await resolvePatient(pSnapId.docs.first.id);

        final uSnap = await db.collection('users').where('abhaNumber', isEqualTo: cleanAbha).limit(1).get();
        if (uSnap.docs.isNotEmpty) return await resolvePatient(uSnap.docs.first.id);

        final uSnapId = await db.collection('users').where('abhaId', isEqualTo: cleanAbha).limit(1).get();
        if (uSnapId.docs.isNotEmpty) return await resolvePatient(uSnapId.docs.first.id);
      } catch (e) {
        dev.log('Search by ABHA error: $e', name: 'PatientResolutionService');
      }
    }

    // 3. Search by Phone Number
    if (phone != null && phone.trim().isNotEmpty) {
      final cleanPhone = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      try {
        final pSnap = await db.collection('patients').where('phone', isEqualTo: cleanPhone).limit(1).get();
        if (pSnap.docs.isNotEmpty) return await resolvePatient(pSnap.docs.first.id);

        final pSnap2 = await db.collection('patients').where('phoneNumber', isEqualTo: cleanPhone).limit(1).get();
        if (pSnap2.docs.isNotEmpty) return await resolvePatient(pSnap2.docs.first.id);

        final uSnap = await db.collection('users').where('phone', isEqualTo: cleanPhone).limit(1).get();
        if (uSnap.docs.isNotEmpty) return await resolvePatient(uSnap.docs.first.id);

        final uSnap2 = await db.collection('users').where('phoneNumber', isEqualTo: cleanPhone).limit(1).get();
        if (uSnap2.docs.isNotEmpty) return await resolvePatient(uSnap2.docs.first.id);
      } catch (e) {
        dev.log('Search by phone error: $e', name: 'PatientResolutionService');
      }
    }

    return null;
  }

  /// Creates or retrieves an existing family relationship between two real accounts
  Future<FamilyRelationshipModel> linkFamilyMember({
    String? ownerUid,
    String? memberUid,
    String? patientId,
    String? familyMemberId,
    required String relationship,
    FamilyRelationshipPermissions permissions = const FamilyRelationshipPermissions(),
    double? customX,
    double? customY,
  }) async {
    final effectiveOwner = ownerUid ?? patientId ?? '';
    final effectiveMember = memberUid ?? familyMemberId ?? '';
    final db = _db;
    if (db == null) throw StateError('Database not initialized');
    if (effectiveOwner.isEmpty || effectiveMember.isEmpty) {
      throw ArgumentError('ownerUid and memberUid must not be empty');
    }
    if (effectiveOwner == effectiveMember) {
      throw ArgumentError('Cannot link an account as a family member of itself.');
    }

    final targetProfile = await resolvePatient(effectiveMember);
    if (targetProfile == null) {
      throw StateError('Target family member account does not exist in Firestore.');
    }

    final relationshipId = 'rel_${effectiveOwner}_$effectiveMember';

    // 1. Check for duplicate relationship
    final existingDoc = await db.collection('familyRelationships').doc(relationshipId).get();
    if (existingDoc.exists) {
      dev.log('[FAMILY] Relationship already exists between $ownerUid and $memberUid. Skipping duplicate creation.', name: 'PatientResolutionService');
      final existingModel = FamilyRelationshipModel.fromFirestore(existingDoc);
      return existingModel.copyWithResolvedData(
        memberName: targetProfile['name'] as String?,
        memberPhone: existingModel.permissions.basicProfile ? targetProfile['phone'] as String? : null,
        memberAbha: existingModel.permissions.basicProfile ? targetProfile['abhaNumber'] as String? : null,
        memberAge: existingModel.permissions.basicProfile ? targetProfile['age'] as int? : null,
        memberAvatar: targetProfile['avatar'] as String?,
        memberHealthStatus: existingModel.permissions.basicProfile ? targetProfile['status'] as String? : null,
      );
    }

    // 2. Count existing relationships of this type to offset siblings/children/parents
    int siblingIndex = 0;
    try {
      final existingOfType = await db
          .collection('familyRelationships')
          .where('ownerUid', isEqualTo: effectiveOwner)
          .where('relationship', isEqualTo: relationship)
          .get();
      siblingIndex = existingOfType.docs.length;
    } catch (_) {}

    // 3. Compute sensible hierarchical 2D coordinates
    final pos = customX != null && customY != null
        ? Offset(customX, customY)
        : FamilyRelationshipModel.calculateSensiblePosition(relationship, siblingIndex: siblingIndex);

    final now = DateTime.now();

    final rel = FamilyRelationshipModel(
      id: relationshipId,
      ownerUid: effectiveOwner,
      memberUid: effectiveMember,
      relationship: relationship,
      status: 'approved',
      permissions: permissions,
      positionX: pos.dx,
      positionY: pos.dy,
      connectedToIds: [effectiveOwner],
      createdAt: now,
      memberName: targetProfile['name'] as String?,
      memberPhone: targetProfile['phone'] as String?,
      memberAbha: targetProfile['abhaNumber'] as String?,
      memberAge: targetProfile['age'] as int?,
      memberAvatar: targetProfile['avatar'] as String?,
      memberHealthStatus: targetProfile['status'] as String?,
    );

    // 4. Write familyRelationships document
    await db.collection('familyRelationships').doc(relationshipId).set(rel.toFirestore());

    // 5. Ensure shared familyChat document exists in familyChats/{chatId} (legacy path)
    final chatId = getFamilyChatId(effectiveOwner, effectiveMember);
    await db.collection('familyChats').doc(chatId).set({
      'chatId': chatId,
      'memberIds': FieldValue.arrayUnion([effectiveOwner, effectiveMember]),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 5b. Also create canonical families/{familyId} doc (used by FamilyChatView stream)
    final sortedUids = [effectiveOwner, effectiveMember]..sort();
    final familyId = 'family_${sortedUids.join("_")}';
    await db.collection('families').doc(familyId).set({
      'familyId': familyId,
      'ownerUid': effectiveOwner,
      'memberIds': FieldValue.arrayUnion([effectiveOwner, effectiveMember]),
      'members': FieldValue.arrayUnion([effectiveOwner, effectiveMember]),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 6. Log activity event
    try {
      await _activityLogService?.logEvent(
        patientId: effectiveOwner,
        eventType: ActivityEventType.familyMemberAdded,
        title: 'Family Member Linked',
        description: 'Linked ${targetProfile["name"]} as $relationship.',
        actorUid: effectiveOwner,
        actorRole: 'patient',
        metadata: {
          'familyMemberId': effectiveMember,
          'relationship': relationship,
          'relationshipId': relationshipId,
        },
      );
    } catch (_) {}

    return rel;
  }

  /// Updates node position in Firestore
  Future<void> updateNodePosition(String relationshipId, double x, double y) async {
    final db = _db;
    if (db == null || relationshipId.isEmpty) return;

    try {
      await db.collection('familyRelationships').doc(relationshipId).update({
        'positionX': x,
        'positionY': y,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('[FAMILY] Failed to update node position: $e', name: 'PatientResolutionService');
    }
  }

  /// Removes a family member relationship
  Future<void> deleteFamilyMember(String relationshipId, String ownerUid) async {
    final db = _db;
    if (db == null || relationshipId.isEmpty) return;

    try {
      await db.collection('familyRelationships').doc(relationshipId).delete();
      await _activityLogService?.logEvent(
        patientId: ownerUid,
        eventType: ActivityEventType.familyMemberRemoved,
        title: 'Family Member Removed',
        description: 'Removed family relationship.',
        actorUid: ownerUid,
        actorRole: 'patient',
        metadata: {'relationshipId': relationshipId},
      );
    } catch (e) {
      dev.log('[FAMILY] Failed to delete family member: $e', name: 'PatientResolutionService');
    }
  }

  /// Generates a canonical shared family chat ID between members
  static String getFamilyChatId(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return 'chat_${sorted[0]}_${sorted[1]}';
  }

  /// Stream of family relationships for a patient, enriched with permitted data
  Stream<List<FamilyRelationshipModel>> streamFamilyRelationships(String patientId) {
    final db = _db;
    if (patientId.isEmpty || db == null) return Stream.value([]);

    return db
        .collection('familyRelationships')
        .where('ownerUid', isEqualTo: patientId)
        .snapshots()
        .asyncMap((snap) async {
          final list = <FamilyRelationshipModel>[];
          for (final doc in snap.docs) {
            final model = FamilyRelationshipModel.fromFirestore(doc);
            final targetProfile = await resolvePatient(model.memberUid);
            if (targetProfile != null) {
              list.add(model.copyWithResolvedData(
                memberName: targetProfile['name'] as String?,
                memberPhone: model.permissions.basicProfile ? targetProfile['phone'] as String? : null,
                memberAbha: model.permissions.basicProfile ? targetProfile['abhaNumber'] as String? : null,
                memberAge: model.permissions.basicProfile ? targetProfile['age'] as int? : null,
                memberAvatar: targetProfile['avatar'] as String?,
                memberHealthStatus: model.permissions.basicProfile ? targetProfile['status'] as String? : null,
              ));
            } else {
              list.add(model);
            }
          }
          return list;
        });
  }
}
