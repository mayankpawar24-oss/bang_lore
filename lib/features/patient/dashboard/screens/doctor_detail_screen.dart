import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';

class DoctorDetailScreen extends ConsumerWidget {
  final String doctorId;
  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctors = ref.watch(doctorsProvider);
    final doctor = doctors.firstWhere((d) => d.id == doctorId, orElse: () => doctors.first);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260.0,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.blueToIndigo),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 36),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      doctor.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doctor.specialty} • ${doctor.hospital}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    borderRadius: 20,
                    elevation: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoStat(LucideIcons.users, 'Patients', '1.5k+', isDark),
                        Container(
                          width: 1,
                          height: 36,
                          color: isDark ? const Color(0xFF334155) : AppColors.border,
                        ),
                        _buildInfoStat(LucideIcons.star, 'Rating', doctor.rating.toStringAsFixed(1), isDark),
                        Container(
                          width: 1,
                          height: 36,
                          color: isDark ? const Color(0xFF334155) : AppColors.border,
                        ),
                        _buildInfoStat(LucideIcons.mapPin, 'Distance', '${doctor.distance} km', isDark),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.05),
                  const SizedBox(height: 24),
                  Text(
                    'About Doctor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
                    child: Text(
                      doctor.about.isNotEmpty
                          ? doctor.about
                          : 'Specialist with extensive clinical expertise providing proactive continuous healthcare coordination.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFCBD5E1) : AppColors.slate,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.05),
                  const SizedBox(height: 24),
                  Text(
                    'Available Days',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: doctor.availableDays.map((day) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                              : AppColors.softBlue,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          day,
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn().slideY(begin: 0.05),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: 'Book Appointment',
                    onPressed: () {
                      context.push('/patient/schedule/book/${doctor.id}');
                    },
                    icon: LucideIcons.calendar,
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStat(IconData icon, String label, String value, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                : AppColors.softBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : AppColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
