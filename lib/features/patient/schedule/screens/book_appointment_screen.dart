import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/doctor_model.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  final String doctorId;
  const BookAppointmentScreen({super.key, required this.doctorId});

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '01:00 PM', '01:30 PM',
    '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int _getSlotState(String timeStr, List<AppointmentModel> myAppts, List<Map<String, dynamic>> docSlots) {
    // 0: available, 1: pending review, 2: booked/reserved
    if (_selectedDay == null) return 0;
    int hour = int.parse(timeStr.substring(0, 2));
    int minute = int.parse(timeStr.substring(3, 5));
    if (timeStr.contains('PM') && hour != 12) hour += 12;
    if (timeStr.contains('AM') && hour == 12) hour = 0;

    final targetDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, hour, minute);

    // 1. Check doctor availability slots from Firestore
    for (final s in docSlots) {
      final ts = s['dateTime'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate();
        if (d.year == targetDate.year &&
            d.month == targetDate.month &&
            d.day == targetDate.day &&
            d.hour == targetDate.hour &&
            d.minute == targetDate.minute) {
          final st = s['status'] as String? ?? 'pending';
          if (st == 'approved' || st == 'confirmed' || st == 'scheduled') {
            return 2; // Reserved
          }
          return 1; // Pending
        }
      }
    }

    // 2. Check patient's own appointments
    for (final a in myAppts) {
      if (a.doctorId != widget.doctorId) continue;
      if (a.dateTime.year == targetDate.year &&
          a.dateTime.month == targetDate.month &&
          a.dateTime.day == targetDate.day &&
          a.dateTime.hour == targetDate.hour &&
          a.dateTime.minute == targetDate.minute) {
        if (a.status == AppointmentStatus.approved ||
            a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.scheduled) {
          return 2; // Booked/Approved
        }
        if (a.status == AppointmentStatus.pending || a.status == AppointmentStatus.requested) {
          return 1; // Pending
        }
      }
    }
    return 0; // Available
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctors = ref.watch(doctorsProvider);
    final doctor = doctors.firstWhere((d) => d.id == widget.doctorId, orElse: () => doctors.first);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      appBar: AppBar(
        title: Text(
          'Book Appointment',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white : AppColors.navy,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              elevation: 1,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softBlue,
                    ),
                    child: ClipOval(
                      child: doctor.avatarUrl.isNotEmpty
                          ? Image.network(
                              doctor.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialty,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(LucideIcons.star, color: AppColors.warning, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              doctor.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 24),
            Text(
              'Select Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(12),
              borderRadius: 20,
              elevation: 1,
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 90)),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedTime = null; // Reset time when date changes
                  });
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: isDark ? Colors.white : AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  leftChevronIcon: Icon(
                    LucideIcons.chevronLeft,
                    color: isDark ? Colors.white : AppColors.navy,
                    size: 20,
                  ),
                  rightChevronIcon: Icon(
                    LucideIcons.chevronRight,
                    color: isDark ? Colors.white : AppColors.navy,
                    size: 20,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: isDark ? Colors.white : AppColors.navy),
                  weekendTextStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.navy),
                  selectedDecoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A) : AppColors.softBlue,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: isDark ? Colors.white : AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 24),
            Text(
              'Select Time Slot',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _timeSlots.length,
              itemBuilder: (context, index) {
                final time = _timeSlots[index];
                final isSelected = _selectedTime == time;
                final myAppts = ref.watch(appointmentsStreamProvider).valueOrNull ?? [];
                final docSlots = ref.watch(doctorAvailabilityStreamProvider(widget.doctorId)).valueOrNull ?? [];
                final slotState = _getSlotState(time, myAppts, docSlots);
                final isUnavailable = slotState != 0;

                Color bgColor;
                Color borderColor;
                Color textColor;
                String? badgeLabel;
                Color? badgeColor;

                if (slotState == 2) {
                  // Booked / Reserved
                  bgColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade200;
                  borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
                  textColor = isDark ? const Color(0xFF64748B) : Colors.grey.shade600;
                  badgeLabel = 'Reserved';
                  badgeColor = AppColors.danger;
                } else if (slotState == 1) {
                  // Pending Request
                  bgColor = isDark ? const Color(0xFF292524) : const Color(0xFFFEF3C7);
                  borderColor = AppColors.warning.withValues(alpha: 0.5);
                  textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
                  badgeLabel = 'Pending';
                  badgeColor = AppColors.warning;
                } else if (isSelected) {
                  bgColor = AppColors.primaryBlue;
                  borderColor = AppColors.primaryBlue;
                  textColor = Colors.white;
                } else {
                  bgColor = isDark ? const Color(0xFF131C2E) : Colors.white;
                  borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border;
                  textColor = isDark ? Colors.white : AppColors.navy;
                }

                return GestureDetector(
                  onTap: isUnavailable
                      ? null
                      : () {
                          setState(() {
                            _selectedTime = time;
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected && !isUnavailable
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                            decoration: slotState == 2 ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (badgeLabel != null)
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 24),
            Text(
              'Notes (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: isDark ? Colors.white : AppColors.navy),
              decoration: InputDecoration(
                hintText: 'Describe your symptoms or reason for visit...',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                filled: true,
                fillColor: isDark ? const Color(0xFF131C2E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 32),
            PrimaryButton(
              label: _isSubmitting ? 'Submitting Request...' : 'Request Appointment',
              onPressed: (_selectedDay != null && _selectedTime != null && !_isSubmitting)
                  ? () => _bookAppointment(doctor, isDark)
                  : null,
              icon: _isSubmitting ? null : LucideIcons.calendarCheck,
            ).animate().fadeIn().slideY(begin: 0.05),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _bookAppointment(DoctorModel doctor, bool isDark) async {
    if (_selectedDay == null || _selectedTime == null) return;
    int hour = int.parse(_selectedTime!.substring(0, 2));
    int minute = int.parse(_selectedTime!.substring(3, 5));
    if (_selectedTime!.contains('PM') && hour != 12) hour += 12;
    if (_selectedTime!.contains('AM') && hour == 12) hour = 0;

    final apptDateTime = DateTime(
      _selectedDay!.year, _selectedDay!.month, _selectedDay!.day,
      hour, minute,
    );

    final user = ref.read(currentUserProvider).valueOrNull ?? ref.read(authProvider).user;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? ref.read(currentUidProvider);

    if (currentUid == null || currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book an appointment')),
      );
      return;
    }

    final appointmentId = const Uuid().v4();
    dev.log('[APPOINTMENT] path being read/written: initiate booking for $currentUid with doctor ${doctor.id}', name: 'BookAppointmentScreen');
    dev.log('[APPOINTMENT] Firebase UID: $currentUid', name: 'BookAppointmentScreen');
    dev.log('[APPOINTMENT] doctorId: ${doctor.id}', name: 'BookAppointmentScreen');
    dev.log('[APPOINTMENT] appointmentId: $appointmentId', name: 'BookAppointmentScreen');

    final appointment = AppointmentModel(
      id: appointmentId,
      patientId: currentUid,
      doctorId: doctor.id,
      doctorName: doctor.name,
      patientName: user?.name ?? 'Patient',
      specialty: doctor.specialty,
      dateTime: apptDateTime,
      durationMinutes: 30,
      status: AppointmentStatus.pending,
      notes: _notesController.text.trim(),
    );

    setState(() => _isSubmitting = true);

    try {
      await ref.read(appointmentRepositoryProvider).bookAppointment(appointment);
      await ref.read(appointmentsProvider.notifier).loadAppointments(currentUid);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 64)
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 16),
              Text(
                'Appointment Request Sent!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your request with ${doctor.name} for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year} at ${_selectedTime!} has been submitted. The doctor will review and confirm.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Go back to previous screen
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      dev.log('[APPOINTMENT] exception: $e', error: e, name: 'BookAppointmentScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
