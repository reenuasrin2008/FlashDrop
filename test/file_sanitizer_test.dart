import 'package:flutter_test/flutter_test.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';

void main() {
  group('FileSanitizer', () {
    test('prevents path traversal attacks', () {
      expect(FileSanitizer.sanitizeFileName('../../etc/passwd'), 'passwd');
      expect(FileSanitizer.sanitizeFileName(r'..\..\Windows\system.ini'), 'system.ini');
      expect(FileSanitizer.sanitizeFileName('....'), 'received_file');
    });

    test('strips illegal characters and preserves extension', () {
      expect(FileSanitizer.sanitizeFileName('my:bad*file?.mp4'), 'my_bad_file_.mp4');
    });

    test('resolves filename collisions cleanly', () {
      final existing = {'photo.jpg', 'photo_(1).jpg'};
      expect(FileSanitizer.resolveCollision('photo.jpg', existing), 'photo_(2).jpg');
    });

    test('formats bytes, speed, and duration', () {
      expect(FileSanitizer.formatBytes(0), '0 B');
      expect(FileSanitizer.formatBytes(1024 * 1024), '1.0 MB');
      expect(FileSanitizer.formatSpeed(10 * 1024 * 1024), '10.0 MB/s');
      expect(FileSanitizer.formatDuration(const Duration(seconds: 75)), '1m 15s');
    });
  });
}
