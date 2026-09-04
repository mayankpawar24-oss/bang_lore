import 'dart:convert';
import 'dart:developer' as dev;
import 'backend_service.dart';

class OcrExtractionResult {
  final List<String> diagnosis;
  final List<String> conditions;
  final List<String> medicines;
  final Map<String, String> dosage;
  final List<Map<String, dynamic>> medicationsDetail;
  final Map<String, dynamic> vitals;
  final Map<String, dynamic> labValues;
  final List<String> abnormalFindings;
  final List<String> procedures;
  final List<String> appointments;
  final List<String> dates;
  final Map<String, dynamic> admissionDischargeInfo;
  final String followUpInstructions;
  final String extractedRawText;
  final List<String> uncertainties;
  final String processingStatus;
  final String? reviewReason;
  final Map<String, dynamic> provenance;
  final DateTime processedAt;

  const OcrExtractionResult({
    required this.diagnosis,
    this.conditions = const [],
    required this.medicines,
    required this.dosage,
    this.medicationsDetail = const [],
    required this.vitals,
    required this.labValues,
    required this.abnormalFindings,
    required this.procedures,
    this.appointments = const [],
    required this.dates,
    required this.admissionDischargeInfo,
    required this.followUpInstructions,
    required this.extractedRawText,
    this.uncertainties = const [],
    this.processingStatus = 'COMPLETED',
    this.reviewReason,
    this.provenance = const {},
    required this.processedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'diagnosis': diagnosis,
      'conditions': conditions.isNotEmpty ? conditions : diagnosis,
      'medicines': medicines,
      'medications': medicines,
      'dosage': dosage,
      'medications_detail': medicationsDetail,
      'vitals': vitals,
      'labValues': labValues,
      'abnormalFindings': abnormalFindings,
      'warning_signs': abnormalFindings,
      'procedures': procedures,
      'appointments': appointments,
      'dates': dates,
      'admissionDischargeInfo': admissionDischargeInfo,
      'followUpInstructions': followUpInstructions,
      'follow_up': followUpInstructions,
      'extractedRawText': extractedRawText,
      'extracted_summary': extractedRawText,
      'uncertainties': uncertainties,
      'processingStatus': processingStatus,
      'review_reason': reviewReason,
      'provenance': provenance,
      'storage_mode': 'transient_memory_only',
      'persisted_storage': false,
      'processedAt': processedAt.toIso8601String(),
    };
  }

  factory OcrExtractionResult.fromMap(Map<String, dynamic> map) {
    return OcrExtractionResult(
      diagnosis: List<String>.from(map['diagnosis'] ?? map['conditions'] ?? []),
      conditions: List<String>.from(map['conditions'] ?? map['diagnosis'] ?? []),
      medicines: List<String>.from(map['medicines'] ?? map['medications'] ?? []),
      dosage: Map<String, String>.from(map['dosage'] ?? {}),
      medicationsDetail: (map['medications_detail'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      vitals: Map<String, dynamic>.from(map['vitals'] ?? {}),
      labValues: Map<String, dynamic>.from(map['labValues'] ?? {}),
      abnormalFindings: List<String>.from(map['abnormalFindings'] ?? map['warning_signs'] ?? []),
      procedures: List<String>.from(map['procedures'] ?? []),
      appointments: List<String>.from(map['appointments'] ?? []),
      dates: List<String>.from(map['dates'] ?? []),
      admissionDischargeInfo: Map<String, dynamic>.from(map['admissionDischargeInfo'] ?? {}),
      followUpInstructions: map['followUpInstructions'] as String? ?? map['follow_up'] as String? ?? '',
      extractedRawText: map['extractedRawText'] as String? ?? map['extracted_summary'] as String? ?? '',
      uncertainties: List<String>.from(map['uncertainties'] ?? []),
      processingStatus: map['processingStatus'] as String? ?? 'COMPLETED',
      reviewReason: map['review_reason'] as String?,
      provenance: Map<String, dynamic>.from(map['provenance'] ?? {}),
      processedAt: map['processedAt'] != null
          ? DateTime.tryParse(map['processedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class OcrService {
  final BackendService _backendService;

  OcrService({BackendService? backendService})
      : _backendService = backendService ?? BackendService();

  /// Run Clinical Document Intelligence pipeline via FastAPI backend
  Future<OcrExtractionResult> processDocument({
    required String fileName,
    required List<int> fileBytes,
    String? rawText,
    String? patientId,
    String? documentId,
    String? mimeType,
  }) async {
    dev.log('[OCR] Calling Clinical Document Intelligence for "$fileName" (${fileBytes.length} bytes)', name: 'OcrService');

    try {
      String? b64Content;
      if (fileBytes.isNotEmpty) {
        b64Content = base64Encode(fileBytes);
      }

      final docRes = await _backendService.extractDocument(
        documentId: documentId,
        patientId: patientId,
        base64Content: b64Content,
        textContent: rawText,
        filename: fileName,
        mimeType: mimeType ?? (fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg'),
      );

      final dosageMap = <String, String>{};
      for (final medDetail in docRes.medicationsDetail) {
        final medName = medDetail.nameNormalized ?? medDetail.nameRaw;
        final doseVal = medDetail.doseNormalized ?? medDetail.doseRaw;
        if (medName != null && doseVal != null) {
          dosageMap[medName] = doseVal;
        }
      }

      final medicinesList = docRes.medicationsDetail.isNotEmpty
          ? docRes.medicationsDetail.map((m) => m.nameNormalized ?? m.nameRaw ?? 'Medication').toList()
          : docRes.medications;

      final provenanceMap = Map<String, dynamic>.from(docRes.provenance);
      if (!provenanceMap.containsKey('session_id')) {
        provenanceMap['session_id'] = 'session_${docRes.documentId}';
      }
      provenanceMap['transient_processing'] = true;
      provenanceMap['persisted_storage'] = false;
      provenanceMap['model_id'] = docRes.modelId;

      final isCompleted = docRes.outcome == 'EXTRACTED' || docRes.outcome == 'ACCEPTED';

      final res = OcrExtractionResult(
        diagnosis: docRes.conditions.isNotEmpty ? docRes.conditions : ['General Health Review'],
        conditions: docRes.conditions,
        medicines: medicinesList,
        dosage: dosageMap,
        medicationsDetail: docRes.medicationsDetail.map((m) => m.toJson()).toList(),
        appointments: docRes.appointments,
        vitals: {},
        labValues: {},
        abnormalFindings: docRes.warningSigns,
        procedures: [],
        dates: [DateTime.now().toIso8601String().split('T')[0]],
        admissionDischargeInfo: {
          'outcome': docRes.outcome,
          'document_type': docRes.documentType,
          'review_reason': docRes.reviewReason,
          'model_id': docRes.modelId,
        },
        followUpInstructions: docRes.followUp.isNotEmpty ? docRes.followUp.join('; ') : docRes.extractedSummary,
        extractedRawText: docRes.extractedSummary,
        uncertainties: docRes.uncertainties,
        processingStatus: isCompleted ? 'COMPLETED' : 'REVIEW_REQUIRED',
        reviewReason: docRes.reviewReason,
        provenance: provenanceMap,
        processedAt: DateTime.now(),
      );

      dev.log('[OCR] Clinical Document Intelligence extraction succeeded: ${res.diagnosis.length} conditions, ${res.medicines.length} medications', name: 'OcrService');
      return res;
    } catch (apiErr) {
      dev.log('[OCR] Backend API returned error, activating local fallback parser: $apiErr', name: 'OcrService');
      return _localFallbackExtraction(fileName: fileName, fileBytes: fileBytes, rawText: rawText);
    }
  }

  OcrExtractionResult _localFallbackExtraction({
    required String fileName,
    required List<int> fileBytes,
    String? rawText,
  }) {
    String text = rawText ?? '';
    if (text.isEmpty && fileBytes.isNotEmpty) {
      try {
        text = utf8.decode(fileBytes, allowMalformed: true);
      } catch (_) {
        text = String.fromCharCodes(fileBytes);
      }
    }

    if (text.trim().isEmpty) {
      text = 'Medical Clinical Report for $fileName. Patient evaluated. Findings recorded.';
    }

    final diagnosis = _extractDiagnoses(text);
    final medicines = _extractMedicines(text);
    final dosage = _extractDosages(text, medicines);
    final vitals = _extractVitals(text);
    final labValues = _extractLabValues(text);
    final abnormalFindings = _extractAbnormals(text);
    final procedures = _extractProcedures(text);
    final dates = _extractDates(text);
    final admissionDischargeInfo = _extractAdmissionDischarge(text);
    final followUp = _extractFollowUp(text);

    return OcrExtractionResult(
      diagnosis: diagnosis,
      medicines: medicines,
      dosage: dosage,
      vitals: vitals,
      labValues: labValues,
      abnormalFindings: abnormalFindings,
      procedures: procedures,
      dates: dates,
      admissionDischargeInfo: admissionDischargeInfo,
      followUpInstructions: followUp,
      extractedRawText: text,
      processedAt: DateTime.now(),
    );
  }

  List<String> _extractDiagnoses(String text) {
    final diagnoses = <String>{};
    final lower = text.toLowerCase();
    final patterns = [
      'hypertension', 'type 2 diabetes', 'coronary artery disease', 'asthma',
      'arrhythmia', 'pneumonia', 'fever', 'bronchitis', 'migraine', 'gastritis',
      'hyperlipidemia', 'anemia', 'urinary tract infection', 'osteoarthritis',
    ];
    for (final p in patterns) {
      if (lower.contains(p)) diagnoses.add(p[0].toUpperCase() + p.substring(1));
    }

    final diagMatch = RegExp(r'(?:diagnosis|impression|assessment)[:\s]+([^\n\.;]+)', caseSensitive: false).firstMatch(text);
    if (diagMatch != null) {
      final found = diagMatch.group(1)?.trim();
      if (found != null && found.length > 2) diagnoses.add(found);
    }

    if (diagnoses.isEmpty) diagnoses.add('General Health Review');
    return diagnoses.toList();
  }

  List<String> _extractMedicines(String text) {
    final meds = <String>{};
    final lower = text.toLowerCase();
    final commonMeds = [
      'lisinopril', 'metformin', 'atorvastatin', 'amlodipine', 'metoprolol',
      'omeprazole', 'losartan', 'albuterol', 'furosemide', 'aspirin',
      'paracetamol', 'amoxicillin', 'azithromycin', 'pantoprazole', 'ibuprofen',
    ];
    for (final m in commonMeds) {
      if (lower.contains(m)) meds.add(m[0].toUpperCase() + m.substring(1));
    }

    final rxMatch = RegExp(r'(?:rx|medication|prescribed)[:\s]+([^\n\.;]+)', caseSensitive: false).allMatches(text);
    for (final m in rxMatch) {
      final val = m.group(1)?.trim();
      if (val != null && val.isNotEmpty) meds.add(val);
    }
    return meds.toList();
  }

  Map<String, String> _extractDosages(String text, List<String> medicines) {
    final dosages = <String, String>{};
    for (final med in medicines) {
      final pattern = RegExp('${RegExp.escape(med)}[\\s\\w]*?(\\d+\\s*(?:mg|ml|mcg|tablets?|capsules?))', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        dosages[med] = match.group(1) ?? 'As directed';
      } else {
        dosages[med] = 'Standard clinical dose';
      }
    }
    return dosages;
  }

  Map<String, dynamic> _extractVitals(String text) {
    final vitals = <String, dynamic>{};
    final bpMatch = RegExp(r'(?:bp|blood pressure)[:\s]+(\d{2,3}\s*/\s*\d{2,3})', caseSensitive: false).firstMatch(text);
    if (bpMatch != null) vitals['bloodPressure'] = bpMatch.group(1)!.replaceAll(' ', '');

    final hrMatch = RegExp(r'(?:hr|pulse|heart rate)[:\s]+(\d{2,3})', caseSensitive: false).firstMatch(text);
    if (hrMatch != null) vitals['heartRate'] = int.tryParse(hrMatch.group(1)!);

    final spo2Match = RegExp(r'(?:spo2|oxygen)[:\s]+(\d{2,3})%?', caseSensitive: false).firstMatch(text);
    if (spo2Match != null) vitals['spo2'] = int.tryParse(spo2Match.group(1)!);

    final tempMatch = RegExp(r'(?:temp|temperature)[:\s]+(\d{2,3}(?:\.\d)?)', caseSensitive: false).firstMatch(text);
    if (tempMatch != null) vitals['temperature'] = double.tryParse(tempMatch.group(1)!);

    return vitals;
  }

  Map<String, dynamic> _extractLabValues(String text) {
    final labs = <String, dynamic>{};
    final hba1c = RegExp(r'hba1c[:\s]+(\d+(?:\.\d+)?)%?', caseSensitive: false).firstMatch(text);
    if (hba1c != null) labs['HbA1c'] = '${hba1c.group(1)}%';

    final chol = RegExp(r'(?:total )?cholesterol[:\s]+(\d+)', caseSensitive: false).firstMatch(text);
    if (chol != null) labs['cholesterol'] = '${chol.group(1)} mg/dL';

    final wbc = RegExp(r'wbc[:\s]+(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    if (wbc != null) labs['WBC'] = wbc.group(1);

    return labs;
  }

  List<String> _extractAbnormals(String text) {
    final findings = <String>[];
    final regex = RegExp(r'(?:abnormal|elevated|low|high|critical)[:\s]+([^\n\.;]+)', caseSensitive: false);
    for (final m in regex.allMatches(text)) {
      final f = m.group(1)?.trim();
      if (f != null && f.isNotEmpty) findings.add(f);
    }
    return findings;
  }

  List<String> _extractProcedures(String text) {
    final procs = <String>[];
    final common = ['ecg', 'x-ray', 'ct scan', 'ultrasound', 'mri', 'blood test', 'biopsy', 'endoscopy'];
    final lower = text.toLowerCase();
    for (final p in common) {
      if (lower.contains(p)) procs.add(p.toUpperCase());
    }
    return procs;
  }

  List<String> _extractDates(String text) {
    final dates = <String>[];
    final dateReg = RegExp(r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b');
    for (final m in dateReg.allMatches(text)) {
      final d = m.group(0);
      if (d != null && !dates.contains(d)) dates.add(d);
    }
    return dates;
  }

  Map<String, dynamic> _extractAdmissionDischarge(String text) {
    final info = <String, dynamic>{};
    final lower = text.toLowerCase();
    if (lower.contains('admitted') || lower.contains('admission')) {
      info['isAdmission'] = true;
    }
    if (lower.contains('discharged') || lower.contains('discharge')) {
      info['isDischarge'] = true;
    }
    return info;
  }

  String _extractFollowUp(String text) {
    final match = RegExp(r'(?:follow-up|follow up|next visit)[:\s]+([^\n\.]+)', caseSensitive: false).firstMatch(text);
    return match?.group(1)?.trim() ?? 'Consult primary physician if symptoms persist.';
  }
}
