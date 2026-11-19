enum TransferItemStatus {
  waiting,
  hashing,
  inProgress,
  verifying,
  completed,
  failed,
  cancelled,
}

class TransferProgress {
  const TransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
    this.currentSpeedBytesPerSec = 0,
    this.averageSpeedBytesPerSec = 0,
    this.estimatedRemaining,
    this.errorMessage,
    this.savedPath,
  });

  final String transferId;
  final int bytesTransferred;
  final int totalBytes;
  final TransferItemStatus status;
  final double currentSpeedBytesPerSec;
  final double averageSpeedBytesPerSec;
  final Duration? estimatedRemaining;
  final String? errorMessage;
  final String? savedPath;

  double get fraction {
    if (totalBytes <= 0) {
      return status == TransferItemStatus.completed ? 1.0 : 0.0;
    }
    return (bytesTransferred / totalBytes).clamp(0.0, 1.0);
  }

  int get percentage => (fraction * 100).round();

  /// Computes real throughput and ETA from elapsed time and transferred bytes.
  static TransferProgress compute({
    required String transferId,
    required int bytesTransferred,
    required int totalBytes,
    required TransferItemStatus status,
    required DateTime startedAt,
    required DateTime now,
    int? previousBytes,
    DateTime? previousSampleTime,
    String? errorMessage,
    String? savedPath,
  }) {
    final elapsedMs = now.difference(startedAt).inMilliseconds;
    final avgSpeed = elapsedMs > 0 ? (bytesTransferred * 1000.0) / elapsedMs : 0.0;

    double currentSpeed = avgSpeed;
    if (previousBytes != null && previousSampleTime != null) {
      final deltaMs = now.difference(previousSampleTime).inMilliseconds;
      final deltaBytes = bytesTransferred - previousBytes;
      if (deltaMs > 0 && deltaBytes >= 0) {
        currentSpeed = (deltaBytes * 1000.0) / deltaMs;
      }
    }

    Duration? eta;
    final remainingBytes = totalBytes - bytesTransferred;
    final effectiveSpeed = currentSpeed > 0 ? currentSpeed : avgSpeed;
    if (remainingBytes > 0 && effectiveSpeed > 0) {
      eta = Duration(milliseconds: ((remainingBytes / effectiveSpeed) * 1000).round());
    } else if (remainingBytes <= 0 && totalBytes > 0) {
      eta = Duration.zero;
    }

    return TransferProgress(
      transferId: transferId,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      status: status,
      currentSpeedBytesPerSec: currentSpeed,
      averageSpeedBytesPerSec: avgSpeed,
      estimatedRemaining: eta,
      errorMessage: errorMessage,
      savedPath: savedPath,
    );
  }
}
