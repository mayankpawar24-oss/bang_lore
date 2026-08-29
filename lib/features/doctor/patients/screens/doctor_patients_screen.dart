import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/models/permission_request_model.dart';

class DoctorPatientsScreen extends ConsumerStatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  ConsumerState<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends ConsumerState<DoctorPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // All, Critical, Attention, Stable

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patientsProvider.notifier).loadPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final authState = ref.watch(authProvider);

    final filteredPatients = patients.where((p) {
      if (_selectedFilter == 'Critical') return p.status == 'critical';
      if (_selectedFilter == 'Attention') return p.status == 'attention';
      if (_selectedFilter == 'Stable') return p.status == 'stable';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'My Patients',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Search & view patient health briefs',
                            style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => context.push('/doctor/patients/scan-qr'),
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                          ),
                          child: const Icon(LucideIcons.qrCode, color: AppColors.primaryBlue, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(patientsProvider.notifier).searchPatients(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search patients by name or condition...',
                      prefixIcon: const Icon(LucideIcons.search, color: AppColors.secondaryText, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Critical', 'Attention', 'Stable'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: AppColors.primaryBlue,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Patient List View
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredPatients.length,
                itemBuilder: (context, index) {
                  final patient = filteredPatients[index];
                  return _buildPatientListItem(patient, authState.user?.id, authState.user?.name)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (40 * index).ms)
                      .slideY(begin: 0.05);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientListItem(PatientModel patient, String? doctorId, String? doctorName) {
    return GestureDetector(
      onTap: () {
        if (patient.isAuthorized) {
          context.push('/doctor/patients/patient/${patient.id}', extra: patient);
        } else {
          _showRequestAccessDialog(patient, doctorId, doctorName);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: patient.isAuthorized
                ? AppColors.border.withValues(alpha: 0.6)
                : AppColors.warning.withValues(alpha: 0.4),
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
            CircleAvatar(
              radius: 22,
              backgroundColor: patient.isAuthorized ? AppColors.softBlue : Colors.grey.shade200,
              child: Text(
                patient.name[0],
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!patient.isAuthorized)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(LucideIcons.lock, size: 12, color: AppColors.warning),
                              SizedBox(width: 4),
                              Text('LOCKED', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${patient.age} yrs • ${patient.condition}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                  if (patient.isAuthorized && patient.vitals != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'HR: ${patient.vitals!['hr'] ?? 74} bpm • SpO₂: ${patient.vitals!['spo2'] ?? 98}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w500),
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
      ),
    );
  }

  void _showRequestAccessDialog(PatientModel patient, String? doctorId, String? doctorName) {
    showModalBottomSheet(
      context: context,
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
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.lock, size: 40, color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              Text(
                'You need patient authorization to access medical records for ${patient.name}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Send Access Request',
                onPressed: () {
                  final docId = doctorId ?? 'd_aisha_01';
                  final docName = doctorName ?? 'Dr. Aisha Patel';
                  final req = PermissionRequestModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    doctorId: docId,
                    doctorName: docName,
                    patientId: patient.id,
                    patientName: patient.name,
                    status: PermissionStatus.pending,
                    requestedAt: DateTime.now(),
                  );
                  ref.read(permissionRequestsProvider.notifier).addRequest(req);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Access request sent to ${patient.name}!'), backgroundColor: AppColors.primaryBlue),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
