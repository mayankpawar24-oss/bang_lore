import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/patient_model.dart';

class DoctorCalendarScreen extends ConsumerStatefulWidget {
  const DoctorCalendarScreen({super.key});

  @override
  ConsumerState<DoctorCalendarScreen> createState() => _DoctorCalendarScreenState();
}

class _DoctorCalendarScreenState extends ConsumerState<DoctorCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final List<String> _customSlots = ['09:00 AM', '10:30 AM', '02:00 PM', '04:30 PM'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(appointmentsProvider.notifier).loadAppointments(user.id);
      }
      ref.read(patientsProvider.notifier).loadPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streamAppts = ref.watch(doctorAppointmentsStreamProvider).valueOrNull;
    final List<AppointmentModel> appointments = streamAppts ?? ref.watch(appointmentsProvider);
    final patients = ref.watch(patientsProvider);

    final selectedDayAppointments = appointments.where((a) => _isSameDay(a.dateTime, _selectedDate)).toList();
    final pendingRequests = appointments.where((a) => a.status == AppointmentStatus.pending || a.status == AppointmentStatus.requested).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor Calendar',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.navy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage consultation schedule & slots',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showAddSlotSheet(context, isDark),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.blueToIndigo,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(LucideIcons.plus, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Add Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Full Month Grid View
              _buildMonthCalendarView(appointments, isDark),
              const SizedBox(height: 24),

              // Pending Requests
              if (pendingRequests.isNotEmpty) ...[
                const SectionHeader(title: 'Appointment Requests', subtitle: 'Pending patient requests'),
                const SizedBox(height: 12),
                ...pendingRequests.map((req) => _buildRequestCard(req, isDark)),
                const SizedBox(height: 24),
              ],

              // Scheduled Appointments for Selected Day
              SectionHeader(
                title: 'Scheduled Consultations',
                subtitle: _formatDateStr(_selectedDate),
              ),
              const SizedBox(height: 14),
              if (selectedDayAppointments.isEmpty)
                AppCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  borderRadius: 20,
                  child: Center(
                    child: Text(
                      'No appointments scheduled for this day.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ...selectedDayAppointments.map((appt) => _buildAppointmentCard(appt, isDark)),
              const SizedBox(height: 24),

              // Availability & Time Slots Section
              const SectionHeader(
                title: 'Availability & Slots',
                subtitle: 'Tap open slots to book a patient consultation',
              ),
              const SizedBox(height: 14),
              _buildSlotsContainer(context, patients, isDark),

              const SizedBox(height: 40),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }

  // Full Month Interactive Grid Calendar
  Widget _buildMonthCalendarView(List<AppointmentModel> appointments, bool isDark) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final monthName = months[_focusedMonth.month - 1];

    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;

    final now = DateTime.now();

    return AppCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      elevation: 1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName ${_focusedMonth.year}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.chevronLeft,
                      color: isDark ? Colors.white : AppColors.navy,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.chevronRight,
                      color: isDark ? Colors.white : AppColors.navy,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox.shrink();
              final dayNum = index - firstWeekday + 1;
              final dayDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);

              final isSelected = _isSameDay(dayDate, _selectedDate);
              final isToday = _isSameDay(dayDate, now);
              final dayAppts = appointments.where((a) => _isSameDay(a.dateTime, dayDate)).toList();

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = dayDate),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : (isToday
                            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                  ? AppColors.primaryBlue
                                  : (isDark ? Colors.white : AppColors.navy)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (dayAppts.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayAppts.take(3).map((a) {
                            final dotColor = a.status == AppointmentStatus.completed
                                ? AppColors.success
                                : (a.status == AppointmentStatus.cancelled ? AppColors.danger : Colors.white);
                            return Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? dotColor : AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(AppointmentModel appt, bool isDark) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 1,
      borderColor: AppColors.warning.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appt.patientName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              StatusChip(label: 'PENDING', status: 'warning'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${appt.specialty} • ${_formatTime(appt.dateTime)}',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'Decline',
                  foregroundColor: AppColors.danger,
                  borderColor: AppColors.danger.withValues(alpha: 0.5),
                  onPressed: () async {
                    final currentDoctor = ref.read(currentDoctorStreamProvider).valueOrNull;
                    await ref.read(appointmentRepositoryProvider).updateStatus(
                          appt.patientId,
                          appt.doctorId,
                          appt.id,
                          AppointmentStatus.rejected,
                          updatedByDoctor: true,
                          doctorName: currentDoctor?.name,
                          patientName: appt.patientName,
                        );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Accept',
                  onPressed: () async {
                    final currentDoctor = ref.read(currentDoctorStreamProvider).valueOrNull;
                    await ref.read(appointmentRepositoryProvider).updateStatus(
                          appt.patientId,
                          appt.doctorId,
                          appt.id,
                          AppointmentStatus.approved,
                          updatedByDoctor: true,
                          doctorName: currentDoctor?.name,
                          patientName: appt.patientName,
                        );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appt, bool isDark) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 0.5,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.stethoscope, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.patientName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${appt.specialty} • ${_formatTime(appt.dateTime)} (${appt.durationMinutes} min)',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: appt.status.name.toUpperCase(),
            status: appt.status == AppointmentStatus.completed ? 'success' : 'primary',
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsContainer(BuildContext context, List<PatientModel> patients, bool isDark) {
    final appointments = ref.watch(doctorAppointmentsStreamProvider).valueOrNull ?? [];

    return AppCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule & Slot Overview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Real-time status of time slots for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _customSlots.map((slot) {
              int hour = int.parse(slot.substring(0, 2));
              int minute = int.parse(slot.substring(3, 5));
              if (slot.contains('PM') && hour != 12) hour += 12;
              if (slot.contains('AM') && hour == 12) hour = 0;
              final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);

              final appt = appointments.firstWhere(
                (a) => a.status != AppointmentStatus.cancelled &&
                    a.dateTime.year == targetDate.year &&
                    a.dateTime.month == targetDate.month &&
                    a.dateTime.day == targetDate.day &&
                    a.dateTime.hour == targetDate.hour &&
                    a.dateTime.minute == targetDate.minute,
                orElse: () => Appointment(
                  id: '',
                  patientId: '',
                  doctorId: '',
                  doctorName: '',
                  patientName: '',
                  specialty: '',
                  dateTime: DateTime(2000),
                  durationMinutes: 0,
                  status: AppointmentStatus.completed,
                ),
              );

              final isBooked = appt.id.isNotEmpty && (appt.status == AppointmentStatus.approved || appt.status == AppointmentStatus.scheduled);
              final isPending = appt.id.isNotEmpty && (appt.status == AppointmentStatus.pending || appt.status == AppointmentStatus.requested);

              final statusColor = isBooked
                  ? AppColors.success
                  : isPending
                      ? AppColors.warning
                      : AppColors.primaryBlue;

              final statusLabel = isBooked
                  ? 'Booked'
                  : isPending
                      ? 'Pending'
                      : 'Open';

              return GestureDetector(
                onTap: isBooked || isPending
                    ? null
                    : () => _bookPatientSlotModal(context, slot, patients, isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.clock, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slot,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _bookPatientSlotModal(BuildContext context, String timeSlot, List<PatientModel> patients, bool isDark) {
    String selectedPatient = patients.isNotEmpty ? patients.first.name : 'Margaret Chen';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131C2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule Slot ($timeSlot)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: ${_formatDateStr(_selectedDate)}',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Patient',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: patients.map((p) => ChoiceChip(
                  label: Text(p.name),
                  selected: selectedPatient == p.name,
                  selectedColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    color: selectedPatient == p.name ? Colors.white : (isDark ? Colors.white : AppColors.primaryBlue),
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setModalState(() => selectedPatient = p.name);
                  },
                )).toList(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Confirm Consultation Slot',
                onPressed: () {
                  final newAppt = AppointmentModel(
                    id: const Uuid().v4(),
                    patientId: 'p_margaret_01',
                    doctorId: 'd_aisha_01',
                    doctorName: 'Dr. Aisha Patel',
                    patientName: selectedPatient,
                    specialty: 'Cardiology Consultation',
                    dateTime: _selectedDate,
                    durationMinutes: 30,
                    status: AppointmentStatus.scheduled,
                  );
                  ref.read(appointmentsProvider.notifier).bookAppointment(newAppt);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Consultation booked for $selectedPatient at $timeSlot!'),
                      backgroundColor: AppColors.primaryBlue,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSlotSheet(BuildContext context, bool isDark) {
    final slotCtrl = TextEditingController(text: '03:30 PM');
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Custom Available Slot',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: slotCtrl, decoration: const InputDecoration(labelText: 'Time Slot', hintText: 'e.g. 03:30 PM')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Time Slot',
              onPressed: () {
                if (slotCtrl.text.isNotEmpty) {
                  setState(() => _customSlots.add(slotCtrl.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New time slot added!'), backgroundColor: AppColors.primaryBlue),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateStr(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
