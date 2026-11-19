import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

class IntegrityService {
  /// Streams the file in chunks on a background Isolate to compute SHA-256 without loading it into RAM.
  Future<String> computeSha256(String filePath) {
    return Isolate.run(() => _computeSha256Sync(filePath));
  }

  Future<bool> verifySha256(String filePath, String expectedChecksum) async {
    final actual = await computeSha256(filePath);
    return actual.toLowerCase() == expectedChecksum.trim().toLowerCase();
  }

  static Future<String> _computeSha256Sync(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found for hashing', filePath);
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
