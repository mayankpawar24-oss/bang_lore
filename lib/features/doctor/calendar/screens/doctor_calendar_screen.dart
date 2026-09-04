import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/app_layout_insets.dart';
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
    final currentDoctorUid = FirebaseAuth.instance.currentUser?.uid ?? ref.watch(currentUidProvider) ?? '';
    final streamAppts = ref.watch(doctorAppointmentsStreamProvider).valueOrNull;
    final List<AppointmentModel> appointments = streamAppts ?? ref.watch(appointmentsProvider);
    final realAssociatedPatients = ref.watch(doctorAssociatedPatientsStreamProvider).valueOrNull;
    final List<PatientModel> patients = realAssociatedPatients ?? ref.watch(patientsProvider);

    final selectedDayAppointments = appointments.where((a) => _isSameDay(a.dateTime, _selectedDate)).toList();
    final pendingRequests = appointments.where((a) => a.status == AppointmentStatus.pending || a.status == AppointmentStatus.requested).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, AppLayoutInsets.bottomSafeInset(context) + 24),
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
              SectionHeader(
                title: 'Availability & Slots',
                subtitle: 'Tap open slots to manage or schedule consultations',
                trailing: IconButton(
                  icon: const Icon(LucideIcons.plusCircle, color: AppColors.primaryBlue),
                  tooltip: 'Add Time Slot',
                  onPressed: () => _showAddSlotModal(context, currentDoctorUid, isDark),
                ),
              ),
              const SizedBox(height: 14),
              _buildSlotsContainer(context, currentDoctorUid, patients, isDark),

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

  Widget _buildSlotsContainer(BuildContext context, String doctorUid, List<PatientModel> patients, bool isDark) {
    final appointments = ref.watch(doctorAppointmentsStreamProvider).valueOrNull ?? [];
    final firestoreSlots = ref.watch(doctorAvailabilityStreamProvider(doctorUid)).valueOrNull ?? [];

    // Extract time strings for the selected date from firestore
    final daySlots = <String>{..._customSlots};
    for (final s in firestoreSlots) {
      final ts = s['dateTime'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate();
        if (d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day) {
          final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
          final minute = d.minute.toString().padLeft(2, '0');
          final ampm = d.hour >= 12 ? 'PM' : 'AM';
          daySlots.add('${hour.toString().padLeft(2, '0')}:$minute $ampm');
        }
      }
    }

    final sortedSlots = daySlots.toList()..sort();

    return AppCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Schedule & Slot Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              InkWell(
                onTap: () => _showAddSlotModal(context, doctorUid, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: const [
                      Icon(LucideIcons.plus, size: 14, color: AppColors.primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        'Add Slot',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            children: sortedSlots.map((slot) {
              int hour = int.parse(slot.substring(0, 2));
              int minute = int.parse(slot.substring(3, 5));
              if (slot.contains('PM') && hour != 12) hour += 12;
              if (slot.contains('AM') && hour == 12) hour = 0;
              final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);

              final appt = appointments.firstWhere(
                (a) => a.status != AppointmentStatus.cancelled &&
                    a.status != AppointmentStatus.rejected &&
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
                    : () => _bookPatientSlotModal(context, slot, doctorUid, patients, isDark),
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

  void _showAddSlotModal(BuildContext context, String doctorUid, bool isDark) {
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, AppLayoutInsets.bottomSafeInset(ctx) + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Doctor Time Slot',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${_formatDateStr(_selectedDate)}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.clock, color: AppColors.primaryBlue),
                      title: const Text('Slot Time', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Chip(
                        label: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: selectedTime);
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Save Time Slot to Firestore',
                      onPressed: () async {
                        final targetDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        final slotKey = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}_${targetDate.hour.toString().padLeft(2, '0')}-${targetDate.minute.toString().padLeft(2, '0')}';

                        dev.log('[DOCTOR AVAILABILITY] Setting slot $slotKey for doctor $doctorUid', name: 'DoctorCalendarScreen');
                        await ref.read(doctorRepositoryProvider).setAvailabilitySlot(doctorUid, {
                          'id': slotKey,
                          'slotId': slotKey,
                          'dateTime': Timestamp.fromDate(targetDate),
                          'status': 'open',
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Availability slot added!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _bookPatientSlotModal(BuildContext context, String timeSlot, String doctorUid, List<PatientModel> patients, bool isDark) {
    final patientList = patients.isNotEmpty ? patients : [
      const PatientModel(
        id: 'consultation_patient',
        name: 'New Consultation Patient',
        age: 30,
        condition: 'General Practice',
        status: 'stable',
        isAuthorized: true,
        conditions: ['General Practice'],
        medicationAdherence: 1.0,
      ),
    ];
    String selectedPatientId = patientList.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131C2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: AppLayoutInsets.bottomSafeInset(ctx) + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Consultation ($timeSlot)',
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
                      children: patientList.map((p) => ChoiceChip(
                        label: Text(p.name),
                        selected: selectedPatientId == p.id,
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: selectedPatientId == p.id ? Colors.white : (isDark ? Colors.white : AppColors.primaryBlue),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedPatientId = p.id);
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Confirm Consultation Slot',
                      onPressed: () async {
                        int hour = int.parse(timeSlot.substring(0, 2));
                        int minute = int.parse(timeSlot.substring(3, 5));
                        if (timeSlot.contains('PM') && hour != 12) hour += 12;
                        if (timeSlot.contains('AM') && hour == 12) hour = 0;
                        final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);

                        final selectedPatientObj = patientList.firstWhere((p) => p.id == selectedPatientId);
                        final doctorName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Doctor';

                        final newAppt = AppointmentModel(
                          id: const Uuid().v4(),
                          patientId: selectedPatientObj.id,
                          doctorId: doctorUid,
                          doctorName: doctorName,
                          patientName: selectedPatientObj.name,
                          specialty: 'Clinical Consultation',
                          dateTime: targetDate,
                          durationMinutes: 30,
                          status: AppointmentStatus.approved,
                        );

                        try {
                          await ref.read(appointmentRepositoryProvider).bookAppointment(newAppt);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Consultation booked for ${selectedPatientObj.name} at $timeSlot!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          dev.log('[APPOINTMENT] exception: $e', name: 'DoctorCalendarScreen');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSlotSheet(BuildContext context, bool isDark) {
    final slotCtrl = TextEditingController(text: '03:30 PM');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, AppLayoutInsets.bottomSafeInset(ctx) + 20),
            child: SingleChildScrollView(
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
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('New time slot added!'), backgroundColor: AppColors.primaryBlue),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
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
