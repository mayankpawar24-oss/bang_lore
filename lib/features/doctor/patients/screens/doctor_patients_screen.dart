import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';

class DoctorPatientsScreen extends ConsumerStatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  ConsumerState<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends ConsumerState<DoctorPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // All, Critical, Attention, Stable

  final List<String> _filters = ['All', 'Critical', 'Attention', 'Stable'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patientsProvider.notifier).loadPatients();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streamPatients = ref.watch(doctorAssociatedPatientsStreamProvider).valueOrNull;
    final List<PatientModel> patients = streamPatients ?? ref.watch(patientsProvider);
    final authState = ref.watch(authProvider);

    final filteredPatients = patients.where((p) {
      if (_selectedFilter == 'Critical') return p.status == 'critical';
      if (_selectedFilter == 'Attention') return p.status == 'attention';
      if (_selectedFilter == 'Stable') return p.status == 'stable';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Patients',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search & view patient health briefs',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push('/doctor/patients/scan-qr'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131C2E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
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
                            child: const Icon(LucideIcons.qrCode, color: AppColors.primaryBlue, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Field
                  AppSearchBar(
                    controller: _searchController,
                    hintText: 'Search patients by name or condition...',
                    onChanged: (val) {
                      ref.read(patientsProvider.notifier).searchPatients(val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips Strip
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFilter = filter),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : (isDark ? const Color(0xFF131C2E) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : AppColors.border),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white : AppColors.navy),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Patient List View
            Expanded(
              child: filteredPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131C2E) : AppColors.softBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.users,
                              size: 36,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No patients found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your search query or filter criteria.',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patient = filteredPatients[index];
                        return _buildPatientListItem(
                          patient,
                          authState.user?.id,
                          authState.user?.name,
                          isDark,
                        ).animate().fadeIn(duration: 250.ms, delay: (30 * index).ms).slideY(begin: 0.04);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientListItem(
    PatientModel patient,
    String? doctorId,
    String? doctorName,
    bool isDark,
  ) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      elevation: 0.5,
      borderColor: !patient.isAuthorized
          ? AppColors.warning.withValues(alpha: 0.4)
          : null,
      onTap: () {
        if (patient.isAuthorized) {
          context.push('/doctor/patients/patient/${patient.id}', extra: patient);
        } else {
          _showRequestAccessDialog(patient, doctorId, doctorName, isDark);
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: patient.isAuthorized
                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue)
                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
            child: Text(
              patient.name.isNotEmpty ? patient.name[0] : 'P',
              style: TextStyle(
                color: patient.isAuthorized ? AppColors.primaryBlue : AppColors.muted,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patient.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!patient.isAuthorized)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(LucideIcons.lock, size: 11, color: AppColors.warning),
                            SizedBox(width: 4),
                            Text(
                              'LOCKED',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.age} yrs • ${patient.condition}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                if (patient.isAuthorized && patient.vitals != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'HR: ${patient.vitals!['hr'] ?? 74} bpm • SpO₂: ${patient.vitals!['spo2'] ?? 98}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (patient.isAuthorized)
            StatusChip(label: patient.status.toUpperCase(), status: patient.status)
          else
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
        ],
      ),
    );
  }

  void _showRequestAccessDialog(
    PatientModel patient,
    String? doctorId,
    String? doctorName,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.lock, size: 36, color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need patient authorization to access medical records for ${patient.name}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Send Access Request',
                onPressed: () async {
                  final realDocUid = ref.read(currentUidProvider);
                  if (realDocUid != null && realDocUid.isNotEmpty) {
                    dev.log('[PERMISSION] [DOCTOR] Requesting access for doctor $realDocUid to patient ${patient.id}', name: 'DoctorPatientsScreen');
                    await ref.read(patientRepositoryProvider).requestAccess(
                          realDocUid,
                          patient.id,
                          permissions: const ['profile', 'vitals', 'medications', 'appointments', 'medicalHistory', 'familyHistory', 'reports', 'aiChat'],
                        );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Access request sent to ${patient.name}!'),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
