import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/doctor_model.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/notification_sheet.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(doctorsProvider.notifier).loadDoctors();
      ref.read(medicationsProvider.notifier).loadMedications('patient_id_margaret');
      ref.read(appointmentsProvider.notifier).loadAppointments('patient_id_margaret');
    });
  }

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsProvider);
    final medications = ref.watch(medicationsProvider);
    final appointments = ref.watch(appointmentsProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    AppointmentModel? nextAppointment;
    if (appointments.isNotEmpty) {
      final upcoming = appointments.where((a) => a.dateTime.isAfter(DateTime.now())).toList();
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        nextAppointment = upcoming.first;
      }
    }

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
                  _buildHeader(context, unreadCount),
                  const SizedBox(height: 24),
                  _buildFindDoctor(context),
                  const SizedBox(height: 24),
                  if (doctors.isNotEmpty) ...[
                    _buildNearbyDoctors(context, doctors),
                    const SizedBox(height: 24),
                  ],
                  _buildTodayMedication(medications),
                  const SizedBox(height: 24),
                  if (nextAppointment != null) ...[
                    _buildNextAppointment(context, nextAppointment),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 80), // Padding for floating AI
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
            ),
            Positioned(
              bottom: 24,
              right: 20,
              child: _buildAIChatButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueToIndigo,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'MC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      'Good morning, ',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Text(
                      'Margaret ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text('👋', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'How can we help today?',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () => NotificationSheet.show(context),
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.bell, color: AppColors.navy, size: 20),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate().scale(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFindDoctor(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      gradientOverlay: AppColors.blueToCyan,
      onTap: () => context.push('/patient/dashboard/doctor-search'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              LucideIcons.search,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Find a Doctor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Book top specialists near you',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.arrowRight,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyDoctors(BuildContext context, List<DoctorModel> doctors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Nearby Doctors',
          actionText: 'See All',
          onActionTap: () => context.push('/patient/dashboard/doctor-search'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: doctors.take(4).length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return _buildDoctorCard(context, doctor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(BuildContext context, DoctorModel doctor) {
    return GlassCard(
      width: 165,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/patient/dashboard/doctor/${doctor.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.softBlue,
                  backgroundImage: doctor.avatarUrl.isNotEmpty ? NetworkImage(doctor.avatarUrl) : null,
                  child: doctor.avatarUrl.isEmpty
                      ? Text(
                          doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                          style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
                        )
                      : null,
                ),
                if (doctor.isAvailable)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            doctor.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.navy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            doctor.specialty,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                doctor.isAvailable ? 'Available' : 'Busy',
                style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.star, color: AppColors.warning, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    doctor.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: AppColors.muted, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '${doctor.distance} km',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMedication(List<MedicationModel> medications) {
    final todayMeds = medications.where((m) {
      final now = DateTime.now();
      return m.date.year == now.year && m.date.month == now.month && m.date.day == now.day;
    }).toList();

    final takenCount = todayMeds.where((m) => m.isTaken).length;
    final totalCount = todayMeds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's Medication",
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$takenCount of $totalCount taken',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (todayMeds.isEmpty)
          const Text('No medications scheduled for today.', style: TextStyle(color: AppColors.secondaryText))
        else ...[
          ...todayMeds.map((med) => _buildMedicationCard(med)),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('View Medication History', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(LucideIcons.arrowRight, color: AppColors.primaryBlue, size: 14),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMedicationCard(MedicationModel med) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: med.isTaken
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.025),
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
              color: med.isTaken
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.pill,
              color: med.isTaken ? AppColors.success : AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${med.name} ${med.dosage}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: med.isTaken ? AppColors.navy : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  med.time,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (med.isTaken)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.check, color: AppColors.success, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Taken',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 200.ms)
          else
            GestureDetector(
              onTap: () {
                ref.read(medicationsProvider.notifier).markAsTaken(med.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark as taken',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNextAppointment(BuildContext context, AppointmentModel appointment) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/patient/schedule'),
      gradientOverlay: const LinearGradient(
        colors: [Color(0xFFEFF6FF), Color(0xFFF0F7FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(LucideIcons.calendar, color: AppColors.primaryBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Next Appointment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                    Icon(LucideIcons.arrowRight, color: AppColors.primaryBlue, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tomorrow, Aug 29 • ${_formatTime(appointment.dateTime)}',
                  style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${appointment.doctorName} • ${appointment.specialty}',
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIChatButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/patient/dashboard/ai-chat'),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.blueToCyan,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(LucideIcons.bot, color: Colors.white, size: 26),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 2.seconds),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
