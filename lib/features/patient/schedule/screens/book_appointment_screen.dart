import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/doctor_model.dart';
import 'package:uuid/uuid.dart';

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

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsProvider);
    final doctor = doctors.firstWhere((d) => d.id == widget.doctorId, orElse: () => doctors.first);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book Appointment', style: TextStyle(color: AppColors.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: doctor.avatarUrl.isNotEmpty ? NetworkImage(doctor.avatarUrl) : null,
                  backgroundColor: AppColors.softBlue,
                  child: doctor.avatarUrl.isEmpty ? Text(doctor.name[0], style: const TextStyle(color: AppColors.primaryBlue)) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(doctor.specialty, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 24),
            const Text('Select Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
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
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: AppColors.softBlue, shape: BoxShape.circle),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 24),
            const Text('Select Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _timeSlots.length,
              itemBuilder: (context, index) {
                final time = _timeSlots[index];
                final isSelected = _selectedTime == time;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTime = time;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.grey.shade300),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 24),
            const Text('Notes (Optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any specific concerns?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Confirm Booking',
              onPressed: _selectedDay != null && _selectedTime != null ? () => _bookAppointment(doctor) : null,
              icon: LucideIcons.check,
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _bookAppointment(DoctorModel doctor) {
    // Parse time to create a full DateTime
    // Assuming simple parsing for mock
    int hour = int.parse(_selectedTime!.substring(0, 2));
    int minute = int.parse(_selectedTime!.substring(3, 5));
    if (_selectedTime!.contains('PM') && hour != 12) hour += 12;
    if (_selectedTime!.contains('AM') && hour == 12) hour = 0;
    
    final apptDateTime = DateTime(
      _selectedDay!.year, _selectedDay!.month, _selectedDay!.day,
      hour, minute
    );

    final appointment = AppointmentModel(
      id: const Uuid().v4(),
      patientId: 'patient_id_margaret',
      doctorId: doctor.id,
      doctorName: doctor.name,
      patientName: 'Margaret Chen',
      specialty: doctor.specialty,
      dateTime: apptDateTime,
      durationMinutes: 30,
      status: AppointmentStatus.scheduled,
      notes: _notesController.text,
    );

    ref.read(appointmentsProvider.notifier).bookAppointment(appointment);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 64).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            const Text('Booking Confirmed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your appointment with ${doctor.name} is scheduled.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context); // Close dialog
                context.pop(); // Go back to previous screen
              },
            )
          ],
        ),
      ),
    );
  }
}
