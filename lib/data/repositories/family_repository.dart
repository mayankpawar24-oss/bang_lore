import '../models/family_member_model.dart';
import '../mock/mock_data.dart';

abstract class FamilyRepository {
  Future<List<FamilyMember>> getFamilyMembers(String patientId);
  Future<FamilyMember> getFamilyMemberById(String id);
  Future<void> updateCareTask(String memberId, String taskId, CareTaskStatus newStatus);
  Future<void> addCareTask(String memberId, CareTask task);
}

class MockFamilyRepository implements FamilyRepository {
  final List<FamilyMember> _members = List.from(MockData.familyMembers);

  @override
  Future<List<FamilyMember>> getFamilyMembers(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _members;
  }

  @override
  Future<FamilyMember> getFamilyMemberById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _members.firstWhere((m) => m.id == id);
  }

  @override
  Future<void> updateCareTask(String memberId, String taskId, CareTaskStatus newStatus) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final memberIndex = _members.indexWhere((m) => m.id == memberId);
    if (memberIndex >= 0) {
      final tasks = List<CareTask>.from(_members[memberIndex].careTasks);
      final taskIndex = tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex >= 0) {
        tasks[taskIndex] = tasks[taskIndex].copyWith(status: newStatus);
        _members[memberIndex] = _members[memberIndex].copyWith(careTasks: tasks);
      }
    }
  }

  @override
  Future<void> addCareTask(String memberId, CareTask task) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final memberIndex = _members.indexWhere((m) => m.id == memberId);
    if (memberIndex >= 0) {
      final tasks = List<CareTask>.from(_members[memberIndex].careTasks);
      tasks.add(task.copyWith(id: 'ct_${DateTime.now().millisecondsSinceEpoch}'));
      _members[memberIndex] = _members[memberIndex].copyWith(careTasks: tasks);
    }
  }
}
