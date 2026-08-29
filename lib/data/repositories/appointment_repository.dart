import '../models/appointment_model.dart';
import '../mock/mock_data.dart';

abstract class AppointmentRepository {
  Future<List<Appointment>> getAppointments(String userId);
  Future<List<Appointment>> getUpcomingAppointments(String userId);
  Future<Appointment> bookAppointment(Appointment appointment);
  Future<void> cancelAppointment(String id);
  Future<Appointment> rescheduleAppointment(String id, DateTime newDateTime);
  Future<List<DateTime>> getAvailableSlots(String doctorId, DateTime date);
}

class MockAppointmentRepository implements AppointmentRepository {
  final List<Appointment> _appointments = List.from(MockData.appointments);

  @override
  Future<List<Appointment>> getAppointments(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _appointments.where((a) => a.patientId == userId || a.doctorId == userId).toList();
  }

  @override
  Future<List<Appointment>> getUpcomingAppointments(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _appointments.where((a) => 
      (a.patientId == userId || a.doctorId == userId) && 
      a.dateTime.isAfter(DateTime.now()) &&
      a.status == AppointmentStatus.scheduled
    ).toList();
  }

  @override
  Future<Appointment> bookAppointment(Appointment appointment) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final newAppt = appointment.copyWith(id: 'app_${DateTime.now().millisecondsSinceEpoch}');
    _appointments.add(newAppt);
    return newAppt;
  }

  @override
  Future<void> cancelAppointment(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _appointments[index] = _appointments[index].copyWith(status: AppointmentStatus.cancelled);
    }
  }

  @override
  Future<Appointment> rescheduleAppointment(String id, DateTime newDateTime) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final updated = _appointments[index].copyWith(dateTime: newDateTime);
      _appointments[index] = updated;
      return updated;
    }
    throw Exception('Appointment not found');
  }

  @override
  Future<List<DateTime>> getAvailableSlots(String doctorId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      DateTime(date.year, date.month, date.day, 9, 0),
      DateTime(date.year, date.month, date.day, 10, 30),
      DateTime(date.year, date.month, date.day, 14, 0),
      DateTime(date.year, date.month, date.day, 16, 30),
    ];
  }
}
