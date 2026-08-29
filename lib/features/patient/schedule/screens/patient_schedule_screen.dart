import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/reminder_model.dart';
import '../../../../data/models/family_member_model.dart';

class PatientScheduleScreen extends ConsumerStatefulWidget {
  const PatientScheduleScreen({super.key});

  @override
  ConsumerState<PatientScheduleScreen> createState() => _PatientScheduleScreenState();
}

class _PatientScheduleScreenState extends ConsumerState<PatientScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appointmentsProvider.notifier).loadAppointments('patient_id_margaret');
      ref.read(remindersProvider.notifier).loadReminders('patient_id_margaret');
      ref.read(familyMembersProvider.notifier).loadFamilyMembers('patient_id_margaret');
    });
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsProvider);
    final reminders = ref.watch(remindersProvider);
    final members = ref.watch(familyMembersProvider);

    final selectedDayAppointments = appointments.where((a) => _isSameDay(a.dateTime, _selectedDate)).toList();
    final selectedDayReminders = reminders.where((r) => _isSameDay(r.dateTime, _selectedDate)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  _buildMonthCalendarView(appointments, reminders),
                  const SizedBox(height: 24),
                  _buildAppointmentsSection(selectedDayAppointments),
                  const SizedBox(height: 24),
                  _buildDoctorAvailabilitySection(context),
                  const SizedBox(height: 28),
                  _buildRemindersSection(selectedDayReminders, members),
                  const SizedBox(height: 100), // Padding for SOS button
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),
            Positioned(
              bottom: 24,
              right: 20,
              child: _buildSosButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Schedule',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
            letterSpacing: -0.5,
          ),
        ),
        GestureDetector(
          onTap: () => _showAddAppointmentSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                Icon(LucideIcons.plus, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // FULL MONTH INTERACTIVE CALENDAR
  Widget _buildMonthCalendarView(List<AppointmentModel> appointments, List<ReminderModel> reminders) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final monthName = months[_focusedMonth.month - 1];

    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // 0 for Sun

    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month & Navigation Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName ${_focusedMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: AppColors.navy, size: 20),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronRight, color: AppColors.navy, size: 20),
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

          // Days of Week Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Month Days Grid
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
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final dayNum = index - firstWeekday + 1;
              final dayDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);

              final isSelected = _isSameDay(dayDate, _selectedDate);
              final isToday = _isSameDay(dayDate, now);
              final hasAppt = appointments.any((a) => _isSameDay(a.dateTime, dayDate));
              final hasRem = reminders.any((r) => _isSameDay(r.dateTime, dayDate));

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = dayDate),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : (isToday ? AppColors.softBlue : Colors.transparent),
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
                              : (isToday ? AppColors.primaryBlue : AppColors.navy),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasAppt)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasRem)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accentCyan : AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
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

  Widget _buildAppointmentsSection(List<AppointmentModel> appointments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Appointments',
          subtitle: _formatDateStr(_selectedDate),
        ),
        const SizedBox(height: 14),
        if (appointments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                'No appointments scheduled for ${_formatDateStr(_selectedDate)}',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
            ),
          )
        else
          ...appointments.map((a) => _buildAppointmentCard(context, a)),
      ],
    );
  }

  Widget _buildAppointmentCard(BuildContext context, AppointmentModel appointment) {
    return GestureDetector(
      onTap: () => _showAppointmentDetailModal(context, appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.stethoscope, color: AppColors.primaryBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.doctorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${appointment.specialty} • ${_formatTime(appointment.dateTime)}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                ],
              ),
            ),
            StatusChip(
              label: appointment.status.name.toUpperCase(),
              status: appointment.status == AppointmentStatus.completed
                  ? 'success'
                  : (appointment.status == AppointmentStatus.cancelled ? 'danger' : 'primary'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorAvailabilitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Doctor Availability & Slots',
          subtitle: 'Connected specialists & open consultation times',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDoctorSlotRow(
                context,
                doctorName: 'Dr. Aisha Patel',
                specialty: 'Cardiology',
                slots: ['10:30 AM', '2:00 PM', '4:30 PM'],
              ),
              const Divider(height: 24),
              _buildDoctorSlotRow(
                context,
                doctorName: 'Dr. James Wilson',
                specialty: 'Neurology',
                slots: ['11:00 AM', '3:15 PM'],
              ),
              const Divider(height: 24),
              _buildDoctorSlotRow(
                context,
                doctorName: 'Dr. Sarah Kim',
                specialty: 'Endocrinology',
                slots: ['9:30 AM', '1:00 PM'],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorSlotRow(
    BuildContext context, {
    required String doctorName,
    required String specialty,
    required List<String> slots,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              doctorName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
            ),
            Text(
              specialty,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            return GestureDetector(
              onTap: () {
                _bookSlot(context, doctorName, specialty, slot);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Text(
                  slot,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _bookSlot(BuildContext context, String doctorName, String specialty, String slotTime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Book $slotTime Slot?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        content: Text('Confirm consultation with $doctorName ($specialty) for ${_formatDateStr(_selectedDate)} at $slotTime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          PrimaryButton(
            label: 'Confirm Booking',
            isFullWidth: false,
            onPressed: () {
              final newAppt = AppointmentModel(
                id: const Uuid().v4(),
                patientId: 'p_margaret_01',
                doctorId: 'd_doctor',
                doctorName: doctorName,
                patientName: 'Margaret Chen',
                specialty: specialty,
                dateTime: _selectedDate,
                durationMinutes: 30,
                status: AppointmentStatus.scheduled,
              );
              ref.read(appointmentsProvider.notifier).bookAppointment(newAppt);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Appointment confirmed with $doctorName!'),
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection(List<ReminderModel> reminders, List<FamilyMemberModel> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Your Reminders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Care reminders for you and family',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showAddReminderSheet(context, members),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.softBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.plus, color: AppColors.primaryBlue, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (reminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: Text(
                'No reminders for this day',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
            ),
          )
        else
          ...reminders.map((r) => _buildReminderCard(r)),
      ],
    );
  }

  Widget _buildReminderCard(ReminderModel reminder) {
    IconData icon;
    Color iconColor;

    switch (reminder.type) {
      case ReminderType.medicine:
        icon = LucideIcons.pill;
        iconColor = AppColors.primaryBlue;
        break;
      case ReminderType.hydration:
        icon = LucideIcons.droplet;
        iconColor = AppColors.accentCyan;
        break;
      case ReminderType.walking:
        icon = LucideIcons.footprints;
        iconColor = AppColors.success;
        break;
      case ReminderType.familyTask:
        icon = LucideIcons.users;
        iconColor = AppColors.warning;
        break;
      default:
        icon = LucideIcons.bell;
        iconColor = AppColors.primaryBlue;
    }

    final assignee = reminder.assignedBy ?? 'Me';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: reminder.isCompleted ? AppColors.surfaceBlue.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: reminder.isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: reminder.isCompleted ? AppColors.secondaryText : AppColors.navy,
                    decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(reminder.dateTime),
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        assignee,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Checkbox(
            value: reminder.isCompleted,
            activeColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (val) {
              ref.read(remindersProvider.notifier).toggleReminder(reminder.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSosButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSosBottomSheet(context),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(LucideIcons.shieldAlert, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text(
              'SOS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
            ),
          ],
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 1.seconds),
    );
  }

  void _showSosBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.shieldAlert, color: AppColors.danger, size: 44),
            ),
            const SizedBox(height: 16),
            const Text('Emergency SOS', style: TextStyle(color: AppColors.danger, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This will alert your family and care team immediately.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
            const SizedBox(height: 28),
            GestureDetector(
              onLongPress: () {
                Navigator.pop(context);
                _showSosSuccess(context);
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger,
                  boxShadow: [
                    BoxShadow(color: AppColors.danger.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
                  ],
                ),
                child: const Center(
                  child: Text('HOLD\nTO\nACTIVATE', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.3)),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 500.ms),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSosSuccess(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 64).animate().scale(),
            const SizedBox(height: 16),
            const Text('SOS Activated', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 20),
            _buildCheckItem('Family notified'),
            _buildCheckItem('Care team notified'),
            _buildCheckItem('Location shared'),
            _buildCheckItem('Health info shared'),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Cancel Emergency',
              onPressed: () => Navigator.pop(context),
              icon: LucideIcons.xCircle,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(LucideIcons.check, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 15, color: AppColors.navy)),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  void _showAppointmentDetailModal(BuildContext context, AppointmentModel appt) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appt.doctorName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text('${appt.specialty} Consultation', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            Text('Date & Time: ${_formatDateStr(appt.dateTime)} at ${_formatTime(appt.dateTime)}', style: const TextStyle(fontSize: 14, color: AppColors.slate)),
            const SizedBox(height: 8),
            Text('Duration: ${appt.durationMinutes} minutes', style: const TextStyle(fontSize: 14, color: AppColors.slate)),
            const SizedBox(height: 8),
            Text('Notes: ${appt.notes ?? "Routine checkup"}', style: const TextStyle(fontSize: 14, color: AppColors.slate)),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showAddAppointmentSheet(BuildContext context) {
    final docCtrl = TextEditingController();
    final specCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Appointment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            TextField(controller: docCtrl, decoration: const InputDecoration(labelText: 'Doctor Name', hintText: 'e.g. Dr. Aisha Patel')),
            const SizedBox(height: 12),
            TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specialty', hintText: 'e.g. Cardiology')),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Book Appointment',
              onPressed: () {
                if (docCtrl.text.isNotEmpty) {
                  final appt = AppointmentModel(
                    id: const Uuid().v4(),
                    patientId: 'p_margaret_01',
                    doctorId: 'd_aisha_01',
                    doctorName: docCtrl.text,
                    patientName: 'Margaret Chen',
                    specialty: specCtrl.text.isNotEmpty ? specCtrl.text : 'General',
                    dateTime: _selectedDate.add(const Duration(hours: 10)),
                    durationMinutes: 30,
                    status: AppointmentStatus.scheduled,
                  );
                  ref.read(appointmentsProvider.notifier).bookAppointment(appt);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, List<FamilyMemberModel> members) {
    final titleCtrl = TextEditingController();
    ReminderType selectedType = ReminderType.medicine;
    String selectedAssignee = 'Myself';

    final assignees = ['Myself', ...members.map((m) => m.name.split(' ')[0])];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Reminder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  IconButton(icon: const Icon(LucideIcons.x, color: AppColors.slate), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Reminder Title', hintText: 'e.g. Take Lisinopril')),
              const SizedBox(height: 16),
              const Text('Reminder Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ReminderType.values.map((type) {
                  final isSelected = selectedType == type;
                  return ChoiceChip(
                    label: Text(type.name.toUpperCase()),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBlue,
                    backgroundColor: AppColors.surfaceBlue,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
                    onSelected: (val) { if (val) setModalState(() => selectedType = type); },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Assign To (Self or Family)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: assignees.map((person) {
                  final isSelected = selectedAssignee == person;
                  return ChoiceChip(
                    label: Text(person),
                    selected: isSelected,
                    selectedColor: AppColors.softBlue,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(color: isSelected ? AppColors.primaryBlue : AppColors.slate, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                    onSelected: (val) { if (val) setModalState(() => selectedAssignee = person); },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save Reminder',
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    final newReminder = ReminderModel(
                      id: const Uuid().v4(),
                      title: titleCtrl.text,
                      description: '',
                      type: selectedType,
                      dateTime: _selectedDate,
                      isCompleted: false,
                      assignedBy: selectedAssignee,
                    );
                    ref.read(remindersProvider.notifier).addReminder(newReminder);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
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
