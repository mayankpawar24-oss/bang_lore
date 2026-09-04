import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../../data/models/report_model.dart';
import '../../data/providers/providers.dart';

class DocumentViewerDialog extends ConsumerWidget {
  final String title;
  final String docId;
  final ReportModel? initialReport;
  final bool isDark;

  const DocumentViewerDialog({
    super.key,
    required this.title,
    required this.docId,
    this.initialReport,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String docId,
    ReportModel? report,
    required bool isDark,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DocumentViewerDialog(
        title: title,
        docId: docId,
        initialReport: report,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Look up structured report from Firestore streams if available
    final streamReports = ref.watch(reportsStreamProvider).valueOrNull ?? [];
    final firestoreReport = initialReport ??
        streamReports.where((r) => r.id == docId || r.documentId == docId).firstOrNull;

    final patientId = ref.watch(currentUidProvider) ?? 'dev-token-patient-alex';

    return FutureBuilder<Map<String, dynamic>?>(
      future: firestoreReport != null
          ? Future.value(null) // Already loaded from Firestore
          : ref.read(backendServiceProvider).getDocumentDetail(patientId, docId).catchError((_) => <String, dynamic>{}),
      builder: (context, snapshot) {
        final isLoading = firestoreReport == null && snapshot.connectionState == ConnectionState.waiting;
        final backendData = snapshot.data;

        // Structured insight fields extracted from Firestore record
        final extractedData = firestoreReport?.extractedData ?? backendData;
        final conditions = List<String>.from(extractedData?['conditions'] ?? extractedData?['diagnosis'] ?? []);
        final medications = List<String>.from(extractedData?['medicines'] ?? extractedData?['medications'] ?? []);
        final dosageMap = Map<String, dynamic>.from(extractedData?['dosage'] ?? {});
        final appointments = List<String>.from(extractedData?['appointments'] ?? []);
        final warningSigns = List<String>.from(extractedData?['warning_signs'] ?? extractedData?['abnormalFindings'] ?? []);
        final followUp = extractedData?['follow_up'] ?? extractedData?['followUpInstructions'] ?? firestoreReport?.followUpInstructions ?? '';
        final uncertainties = List<String>.from(extractedData?['uncertainties'] ?? []);
        final provenance = Map<String, dynamic>.from(extractedData?['provenance'] ?? {});

        final processingStatus = firestoreReport?.ocrCompleted == true
            ? (extractedData?['processingStatus'] ?? 'COMPLETED')
            : (backendData?['processing_status'] ?? 'COMPLETED');
        final isReview = processingStatus == 'REVIEW_REQUIRED';

        final summary = firestoreReport?.summary ??
            extractedData?['extracted_summary'] ??
            extractedData?['extractedRawText'] ??
            'Structured clinical facts extracted from document.';

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.fileCheck, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firestoreReport?.title ?? backendData?['filename']?.toString() ?? title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firestoreReport?.category.name.toUpperCase() ?? 'CLINICAL DOCUMENT',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              width: double.maxFinite,
              child: isLoading
                  ? const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Badges Row
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isReview ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (isReview ? AppColors.warning : AppColors.success).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isReview ? LucideIcons.alertTriangle : LucideIcons.checkCircle2,
                                      size: 12,
                                      color: isReview ? AppColors.warning : AppColors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      processingStatus.toString().toUpperCase(),
                                      style: TextStyle(
                                        color: isReview ? AppColors.warning : AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                                ),
                              child: const Text(
                                'Zero Storage (In-Memory)',
                                style: TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Clinical Summary
                        _buildSectionHeader('Clinical Summary', LucideIcons.fileText, isDark),
                        const SizedBox(height: 4),
                        Text(
                          summary.toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: isDark ? Colors.white70 : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Extracted Medications & Dosages
                        if (medications.isNotEmpty) ...[
                          _buildSectionHeader('Extracted Medications & Dosages', LucideIcons.pill, isDark),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: medications.map((med) {
                              final dose = dosageMap[med]?.toString() ?? '';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  dose.isNotEmpty ? ' • ' : med,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.primaryBlue,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Extracted Conditions
                        if (conditions.isNotEmpty) ...[
                          _buildSectionHeader('Identified Conditions', LucideIcons.activity, isDark),
                          const SizedBox(height: 6),
                          ...conditions.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 3.0),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.dot, size: 16, color: AppColors.primaryBlue),
                                    Expanded(
                                      child: Text(
                                        c,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : AppColors.navy,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 14),
                        ],

                        // Follow-up Instructions & Appointments
                        if (followUp.toString().isNotEmpty || appointments.isNotEmpty) ...[
                          _buildSectionHeader('Follow-Up & Instructions', LucideIcons.calendarCheck, isDark),
                          const SizedBox(height: 4),
                          if (followUp.toString().isNotEmpty)
                            Text(
                              followUp.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : AppColors.navy,
                              ),
                            ),
                          if (appointments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Appointments: ',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                              ),
                            ),
                          const SizedBox(height: 14),
                        ],

                        // Warning Signs
                        if (warningSigns.isNotEmpty) ...[
                          _buildSectionHeader('Warning Signs Flagged', LucideIcons.alertTriangle, isDark, color: AppColors.danger),
                          const SizedBox(height: 4),
                          ...warningSigns.map((w) => Text(
                                '• ',
                                style: const TextStyle(fontSize: 12, color: AppColors.danger),
                              )),
                          const SizedBox(height: 14),
                        ],

                        // Uncertainties & Clinical Limitations
                        if (uncertainties.isNotEmpty) ...[
                          _buildSectionHeader('Clinical Uncertainties / Boundary', LucideIcons.shieldAlert, isDark, color: AppColors.warning),
                          const SizedBox(height: 4),
                          ...uncertainties.map((u) => Text(
                                '• ',
                                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                              )),
                          const SizedBox(height: 14),
                        ],

                        // Session Provenance
                        _buildSectionHeader('Session Provenance', LucideIcons.fingerprint, isDark),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetaLine('Session ID', provenance['session_id'] ?? 'session_', isDark),
                              _buildMetaLine('Pipeline', provenance['pipeline'] ?? 'ClinicalDocumentIntelligenceService', isDark),
                              _buildMetaLine('Model ID', provenance['model_id'] ?? 'gemini-3.1-flash-lite', isDark),
                              _buildMetaLine('Storage Reference', 'None (Transient In-Memory Only)', isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark, {Color? color}) {
    final c = color ?? (isDark ? const Color(0xFF94A3B8) : AppColors.muted);
    return Row(
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: c,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaLine(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white38 : AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}
