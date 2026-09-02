import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_member_model.dart';

abstract class FamilyRepository {
  Future<List<FamilyMember>> getFamilyMembers(String patientId);
  Future<FamilyMember> getFamilyMemberById(String id);
  Future<void> updateCareTask(String memberId, String taskId, CareTaskStatus newStatus);
  Future<void> addCareTask(String memberId, CareTask task);
  Future<FamilyMember> addFamilyMember(String patientId, FamilyMember member);
  Future<void> updateFamilyMember(String patientId, FamilyMember member);
  Future<void> deleteFamilyMember(String patientId, String memberId);
  Stream<List<FamilyMember>> familyMembersStream(String patientId);
}

class FirebaseFamilyRepository implements FamilyRepository {
  final FirebaseFirestore _db;
  FirebaseFamilyRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _membersCol(String patientId) =>
      _db.collection('patients').doc(patientId).collection('familyMembers');

  @override
  Stream<List<FamilyMember>> familyMembersStream(String patientId) {
    return _membersCol(patientId)
        .orderBy('generation')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FamilyMember.fromFirestore(d)).toList());
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers(String patientId) async {
    final snap = await _membersCol(patientId).orderBy('generation').get();
    return snap.docs.map((d) => FamilyMember.fromFirestore(d)).toList();
  }

  @override
  Future<FamilyMember> getFamilyMemberById(String id) async {
    throw UnimplementedError('Use getFamilyMembers and filter by id');
  }

  @override
  Future<void> updateCareTask(String memberId, String taskId, CareTaskStatus newStatus) async {
    // Not directly supported — requires fetching the doc and merging
    throw UnimplementedError('Use updateFamilyMember instead');
  }

  @override
  Future<void> addCareTask(String memberId, CareTask task) async {
    throw UnimplementedError('Use updateFamilyMember instead');
  }

  @override
  Future<FamilyMember> addFamilyMember(String patientId, FamilyMember member) async {
    final ref = _membersCol(patientId).doc();
    final withId = member.copyWith(id: ref.id);
    await ref.set(withId.toFirestore());
    return withId;
  }

  @override
  Future<void> updateFamilyMember(String patientId, FamilyMember member) async {
    await _membersCol(patientId).doc(member.id).set(
          member.toFirestore(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteFamilyMember(String patientId, String memberId) async {
    await _membersCol(patientId).doc(memberId).delete();
  }
}

// Keep mock for dev fallback
class MockFamilyRepository implements FamilyRepository {
  final List<FamilyMember> _members = [];

  @override
  Stream<List<FamilyMember>> familyMembersStream(String patientId) {
    return Stream.value(List.from(_members));
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers(String patientId) async {
    return List.from(_members);
  }

  @override
  Future<FamilyMember> getFamilyMemberById(String id) async {
    return _members.firstWhere((m) => m.id == id);
  }

  @override
  Future<void> updateCareTask(String memberId, String taskId, CareTaskStatus newStatus) async {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx >= 0) {
      final tasks = List<CareTask>.from(_members[idx].careTasks);
      final ti = tasks.indexWhere((t) => t.id == taskId);
      if (ti >= 0) tasks[ti] = tasks[ti].copyWith(status: newStatus);
      _members[idx] = _members[idx].copyWith(careTasks: tasks);
    }
  }

  @override
  Future<void> addCareTask(String memberId, CareTask task) async {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx >= 0) {
      final tasks = List<CareTask>.from(_members[idx].careTasks)..add(task);
      _members[idx] = _members[idx].copyWith(careTasks: tasks);
    }
  }

  @override
  Future<FamilyMember> addFamilyMember(String patientId, FamilyMember member) async {
    final withId = member.copyWith(id: 'fm_');
    _members.add(withId);
    return withId;
  }

  @override
  Future<void> updateFamilyMember(String patientId, FamilyMember member) async {
    final idx = _members.indexWhere((m) => m.id == member.id);
    if (idx >= 0) _members[idx] = member;
  }

  @override
  Future<void> deleteFamilyMember(String patientId, String memberId) async {
    _members.removeWhere((m) => m.id == memberId);
  }
}
