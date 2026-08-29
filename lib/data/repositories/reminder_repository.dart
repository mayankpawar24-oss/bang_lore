import '../models/reminder_model.dart';
import '../mock/mock_data.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> getReminders(String userId);
  Future<Reminder> addReminder(Reminder reminder);
  Future<void> completeReminder(String id);
  Future<void> deleteReminder(String id);
}

class MockReminderRepository implements ReminderRepository {
  final List<Reminder> _reminders = List.from(MockData.reminders);

  @override
  Future<List<Reminder>> getReminders(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _reminders;
  }

  @override
  Future<Reminder> addReminder(Reminder reminder) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newReminder = reminder.copyWith(id: 'rem_${DateTime.now().millisecondsSinceEpoch}');
    _reminders.add(newReminder);
    return newReminder;
  }

  @override
  Future<void> completeReminder(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _reminders[index] = _reminders[index].copyWith(isCompleted: true);
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _reminders.removeWhere((r) => r.id == id);
  }
}
