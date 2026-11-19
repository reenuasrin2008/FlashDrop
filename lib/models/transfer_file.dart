import 'dart:convert';

import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/core/errors/flashdrop_exception.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';

class TransferFile {
  const TransferFile({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.mimeType,
    this.checksum,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final String mimeType;
  final String? checksum;

  TransferFile copyWith({String? checksum, String? path}) {
    return TransferFile(
      id: id,
      name: name,
      path: path ?? this.path,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      checksum: checksum ?? this.checksum,
    );
  }
}

class TransferMetadata {
  const TransferMetadata({
    required this.protocolVersion,
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.checksum,
    required this.fileIndex,
    required this.totalFiles,
  });

  final int protocolVersion;
  final String transferId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String checksum;
  final int fileIndex;
  final int totalFiles;

  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  Map<String, dynamic> toJson() => {
        'messageType': 'metadata',
        'protocolVersion': protocolVersion,
        'transferId': transferId,
        'fileName': FileSanitizer.sanitizeFileName(fileName),
        'fileSize': fileSize,
        'mimeType': mimeType,
        'checksum': checksum,
        'fileIndex': fileIndex,
        'totalFiles': totalFiles,
      };

  String toJsonString() => jsonEncode(toJson());

  factory TransferMetadata.fromJson(Map<String, dynamic> json) {
    final version = json['protocolVersion'] as int? ?? AppConstants.protocolVersion;
    final transferId = (json['transferId'] as String? ?? '').trim();
    final rawName = (json['fileName'] as String? ?? '').trim();
    final fileSize = json['fileSize'];
    final mimeType = (json['mimeType'] as String? ?? 'application/octet-stream').trim();
    final checksum = (json['checksum'] as String? ?? '').trim();
    final fileIndex = json['fileIndex'] as int? ?? 1;
    final totalFiles = json['totalFiles'] as int? ?? 1;

    if (version != AppConstants.protocolVersion) {
      throw FlashDropException(
        FlashDropErrorCode.invalidMetadata,
        'Unsupported protocol version: $version',
      );
    }
    if (transferId.isEmpty) {
      throw const FlashDropException(
        FlashDropErrorCode.invalidMetadata,
        'Missing transferId in metadata',
      );
    }
    if (rawName.isEmpty) {
      throw const FlashDropException(
        FlashDropErrorCode.invalidMetadata,
        'Missing fileName in metadata',
      );
    }
    if (fileSize is! int || fileSize < 0) {
      throw const FlashDropException(
        FlashDropErrorCode.invalidMetadata,
        'Invalid fileSize in metadata',
      );
    }
    if (!_sha256Pattern.hasMatch(checksum)) {
      throw const FlashDropException(
        FlashDropErrorCode.invalidMetadata,
        'Invalid SHA-256 checksum format in metadata',
      );
    }
    if (fileIndex < 1 || totalFiles < 1 || fileIndex > totalFiles) {
      throw const FlashDropException(
        FlashDropErrorCode.invalidMetadata,
        'Invalid queue index ($fileIndex/$totalFiles)',
      );
    }

    return TransferMetadata(
      protocolVersion: version,
      transferId: transferId,
      fileName: FileSanitizer.sanitizeFileName(rawName),
      fileSize: fileSize,
      mimeType: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
      checksum: checksum.toLowerCase(),
      fileIndex: fileIndex,
      totalFiles: totalFiles,
    );
  }
}
