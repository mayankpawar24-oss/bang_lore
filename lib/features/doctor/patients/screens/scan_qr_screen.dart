import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/patient_model.dart';
import '../../../../data/models/permission_request_model.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  bool _isScanning = false;
  PatientModel? _scannedPatient;

  void _simulateScan() async {
    setState(() {
      _isScanning = true;
      _scannedPatient = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final patients = ref.read(patientsProvider);
    if (patients.isNotEmpty) {
      setState(() {
        _isScanning = false;
        // Mock finding a specific patient or first patient
        _scannedPatient = patients.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Patient QR', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Mock Camera Viewfinder
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  // Corner markers
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                  
                  // Scanning animation
                  if (_isScanning)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentCyan.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .moveY(begin: 0, end: 246, duration: 1500.ms),
                ],
              ),
            ),
          ),
          
          // Bottom Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scannedPatient == null) ...[
                    Text(
                      'Position QR code in frame',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan a patient\'s Continuum Health QR code to access their profile or request permission.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Simulate Scan',
                      isLoading: _isScanning,
                      icon: LucideIcons.scan,
                      onPressed: _simulateScan,
                    ),
                  ] else ...[
                    Icon(LucideIcons.checkCircle, color: AppColors.success, size: 48)
                        .animate().scale().fadeIn(),
                    const SizedBox(height: 16),
                    Text(
                      'Patient Identified',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      _scannedPatient!.name,
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (_scannedPatient!.isAuthorized)
                      PrimaryButton(
                        label: 'Open Patient Brief',
                        onPressed: () {
                          context.pushReplacement('/doctor/patient/${_scannedPatient!.id}', extra: _scannedPatient);
                        },
                      )
                    else
                      PrimaryButton(
                        label: 'Request Access',
                        onPressed: () {
                          final authState = ref.read(authProvider);
                          if (authState.user != null) {
                            final req = PermissionRequestModel(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              doctorId: authState.user!.id,
                              doctorName: authState.user!.name,
                              patientId: _scannedPatient!.id,
                              patientName: _scannedPatient!.name,
                              status: PermissionStatus.pending,
                              requestedAt: DateTime.now(),
                            );
                            ref.read(permissionRequestsProvider.notifier).addRequest(req);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Access request sent to ${_scannedPatient!.name}')),
                            );
                            context.pop();
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _scannedPatient = null;
                        });
                      },
                      child: const Text('Scan Another'),
                    ),
                  ],
                ],
              ),
            ),
          ).animate().slideY(begin: 1.0, duration: 300.ms),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight) 
                ? BorderSide(color: AppColors.primaryBlue, width: 4) : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight) 
                ? BorderSide(color: AppColors.primaryBlue, width: 4) : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft) 
                ? BorderSide(color: AppColors.primaryBlue, width: 4) : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight) 
                ? BorderSide(color: AppColors.primaryBlue, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft ? const Radius.circular(24) : Radius.zero,
            topRight: alignment == Alignment.topRight ? const Radius.circular(24) : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft ? const Radius.circular(24) : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight ? const Radius.circular(24) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
