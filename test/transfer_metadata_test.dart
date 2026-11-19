import 'package:flutter_test/flutter_test.dart';
import 'package:flashdrop/core/errors/flashdrop_exception.dart';
import 'package:flashdrop/models/transfer_file.dart';

void main() {
  const validHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  group('TransferMetadata', () {
    test('round-trips valid metadata and sanitizes path traversal', () {
      final meta = TransferMetadata.fromJson({
        'protocolVersion': 1,
        'transferId': 'tx-001',
        'fileName': '../secrets/report.pdf',
        'fileSize': 4096,
        'mimeType': 'application/pdf',
        'checksum': validHash,
        'fileIndex': 1,
        'totalFiles': 2,
      });
      expect(meta.fileName, 'report.pdf');
      expect(meta.fileSize, 4096);
      expect(meta.checksum, validHash);
    });

    test('rejects invalid SHA-256 checksum', () {
      expect(
        () => TransferMetadata.fromJson({
          'protocolVersion': 1,
          'transferId': 'tx-002',
          'fileName': 'video.mp4',
          'fileSize': 1024,
          'checksum': 'not-a-sha256',
          'fileIndex': 1,
          'totalFiles': 1,
        }),
        throwsA(isA<FlashDropException>()),
      );
    });

    test('rejects negative file size', () {
      expect(
        () => TransferMetadata.fromJson({
          'protocolVersion': 1,
          'transferId': 'tx-003',
          'fileName': 'video.mp4',
          'fileSize': -5,
          'checksum': validHash,
          'fileIndex': 1,
          'totalFiles': 1,
        }),
        throwsA(isA<FlashDropException>()),
      );
    });
  });
}
