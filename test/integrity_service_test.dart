import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flashdrop/services/integrity_service.dart';

void main() {
  group('IntegrityService', () {
    late Directory tempDir;
    late IntegrityService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flashdrop_hash_test_');
      service = IntegrityService();
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('computes exact SHA-256 for file contents and detects tampering', () async {
      final file = File('${tempDir.path}/sample.txt');
      file.writeAsStringSync('FlashDrop offline P2P verification');

      final hash = await service.computeSha256(file.path);
      expect(hash.length, 64);
      expect(await service.verifySha256(file.path, hash), isTrue);

      file.writeAsStringSync('Tampered payload');
      expect(await service.verifySha256(file.path, hash), isFalse);
    });
  });
}
