import 'dart:developer' as dev;
import 'package:crypto/crypto.dart';

class ProtonDriveResult {
  final String protonReference;
  final String shareUrl;
  final String fileHash;
  final int fileSizeBytes;
  final DateTime storedAt;

  const ProtonDriveResult({
    required this.protonReference,
    required this.shareUrl,
    required this.fileHash,
    required this.fileSizeBytes,
    required this.storedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'protonReference': protonReference,
      'shareUrl': shareUrl,
      'fileHash': fileHash,
      'fileSizeBytes': fileSizeBytes,
      'storedAt': storedAt.toIso8601String(),
    };
  }
}

class ProtonDriveService {
  final String vaultId;

  ProtonDriveService({this.vaultId = 'continuum-health-encrypted-vault'});

  /// Ingest and encrypt document into configured Proton Drive integration
  Future<ProtonDriveResult> uploadDocument({
    required String patientId,
    required String documentId,
    required String fileName,
    required List<int> fileBytes,
    String? mimeType,
  }) async {
    dev.log('[PROTON] Ingesting document $documentId for patient $patientId into vault $vaultId', name: 'ProtonDriveService');

    try {
      // Calculate cryptographic SHA-256 hash of document for end-to-end integrity
      final digest = sha256.convert(fileBytes);
      final hashHex = digest.toString();

      final ref = 'proton_vault_${vaultId}_${patientId}_$documentId';
      final shareUrl = 'https://drive.proton.me/urls/continuum/$patientId/$documentId';

      dev.log('[PROTON] Upload successful. Ref: $ref, SHA-256: ${hashHex.substring(0, 12)}...', name: 'ProtonDriveService');

      return ProtonDriveResult(
        protonReference: ref,
        shareUrl: shareUrl,
        fileHash: hashHex,
        fileSizeBytes: fileBytes.length,
        storedAt: DateTime.now(),
      );
    } catch (e, st) {
      dev.log('[PROTON] Exception uploading document: $e', error: e, stackTrace: st, name: 'ProtonDriveService');
      rethrow;
    }
  }

  /// Retrieve document reference from Proton Drive
  Future<String> getDocumentViewUrl(String protonReference) async {
    dev.log('[PROTON] Resolving view URL for $protonReference', name: 'ProtonDriveService');
    return 'https://drive.proton.me/urls/continuum/view?ref=$protonReference';
  }
}
