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
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/doctor_card.dart';
import '../../../../core/widgets/medication_card.dart';
import '../../../../core/widgets/appointment_card.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, ref, unreadCount, isDark),
                  const SizedBox(height: 20),
                  AppSearchBar(
                    readOnly: true,
                    hintText: 'Search specialists, symptoms, clinics...',
                    onTap: () => context.push('/patient/dashboard/doctor-search'),
                    onFilterTap: () => context.push('/patient/dashboard/doctor-search'),
                  ),
                  const SizedBox(height: 20),
                  _buildFindDoctorBanner(context, isDark),
                  const SizedBox(height: 24),
                  if (doctors.isNotEmpty) ...[
                    _buildNearbyDoctors(context, doctors),
                    const SizedBox(height: 24),
                  ],
                  _buildTodayMedication(medications, isDark),
                  const SizedBox(height: 24),
                  if (nextAppointment != null) ...[
                    _buildNextAppointment(context, nextAppointment),
                    const SizedBox(height: 24),
                  ],
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int unreadCount, bool isDark) {
    final userAsync = ref.watch(currentUserProvider);
    final patientAsync = ref.watch(currentPatientStreamProvider);

    final fullName = patientAsync.valueOrNull?.name ??
        userAsync.valueOrNull?.name ??
        ref.watch(authProvider).user?.name ??
        'User';

    final firstName = fullName.trim().isEmpty ? 'User' : fullName.trim().split(' ').first;

    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
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
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      firstName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navy,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 17)),
                  ],
                ),
              ],
            ),
          ],
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => NotificationSheet.show(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.border.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.bell,
                    color: isDark ? Colors.white : AppColors.navy,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0A0F1D) : Colors.white,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ).animate().scale(duration: 200.ms),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFindDoctorBanner(BuildContext context, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: 20,
      elevation: 2,
      onTap: () => context.push('/patient/dashboard/doctor-search'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.stethoscope,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Find Top Specialists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Book verified doctors near you',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.arrowRight,
              color: Colors.white,
              size: 18,
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
          title: 'Our Specialists',
          actionText: 'See All',
          onActionTap: () => context.push('/patient/dashboard/doctor-search'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: doctors.take(4).length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return DoctorCard(
                name: doctor.name,
                specialty: doctor.specialty,
                avatarUrl: doctor.avatarUrl,
                rating: doctor.rating,
                distanceKm: doctor.distance,
                isAvailable: doctor.isAvailable,
                onTap: () => context.push('/patient/dashboard/doctor/${doctor.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTodayMedication(List<MedicationModel> medications, bool isDark) {
    final now = DateTime.now();
    final todayMeds = medications.where((m) {
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
              color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 1,
              ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131C2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            child: const Center(
              child: Text(
                'No medications scheduled for today.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            ),
          )
        else ...[
          ...todayMeds.map(
            (med) => MedicationCard(
              name: med.name,
              dosage: med.dosage,
              time: med.time,
              isTaken: med.isTaken,
              onMarkAsTaken: () {
                ref.read(medicationsProvider.notifier).markAsTaken(med.id);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNextAppointment(BuildContext context, AppointmentModel appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Upcoming Consultation',
        ),
        const SizedBox(height: 14),
        AppointmentCard(
          title: appointment.doctorName,
          subtitle: appointment.specialty,
          dateTime: appointment.dateTime,
          onTap: () => context.push('/patient/schedule'),
        ),
      ],
    );
  }
}
