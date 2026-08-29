import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';

class DoctorDetailScreen extends ConsumerWidget {
  final String doctorId;
  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(doctorsProvider);
    final doctor = doctors.firstWhere((d) => d.id == doctorId, orElse: () => doctors.first);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.blueGradient),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: doctor.avatarUrl.isNotEmpty ? NetworkImage(doctor.avatarUrl) : null,
                      child: doctor.avatarUrl.isEmpty
                          ? Text(doctor.name.substring(0, 1), style: const TextStyle(color: AppColors.primaryBlue, fontSize: 36, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      doctor.name,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      doctor.specialty,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoStat(LucideIcons.users, 'Patients', '1.5k+'),
                      _buildInfoStat(LucideIcons.star, 'Rating', doctor.rating.toStringAsFixed(1)),
                      _buildInfoStat(LucideIcons.mapPin, 'Distance', '${doctor.distance} km'),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 32),
                  const Text('About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Text(
                    doctor.about,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  const Text('Available Days', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: doctor.availableDays.map((day) {
                      return Chip(
                        label: Text(day),
                        backgroundColor: AppColors.softBlue.withOpacity(0.3),
                        labelStyle: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: 'Book Appointment',
                    onPressed: () {
                      context.push('/patient/appointment/book/${doctor.id}');
                    },
                    icon: LucideIcons.calendar,
                  ).animate().fadeIn().slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.softBlue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 28),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
