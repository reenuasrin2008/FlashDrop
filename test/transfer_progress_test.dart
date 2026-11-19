import 'package:flutter_test/flutter_test.dart';
import 'package:flashdrop/models/transfer_progress.dart';

void main() {
  group('TransferProgress.compute', () {
    test('calculates real speed, percentage, and ETA', () {
      final start = DateTime(2026, 11, 20, 10, 0, 0);
      final now = start.add(const Duration(seconds: 2));
      final progress = TransferProgress.compute(
        transferId: 'tx-1',
        bytesTransferred: 20 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
        status: TransferItemStatus.inProgress,
        startedAt: start,
        now: now,
      );

      expect(progress.percentage, 20);
      expect(progress.averageSpeedBytesPerSec, closeTo(10 * 1024 * 1024, 1));
      expect(progress.estimatedRemaining?.inSeconds, 8);
    });
  });
}
