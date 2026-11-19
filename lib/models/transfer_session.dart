import 'package:flashdrop/models/transfer_file.dart';
import 'package:flashdrop/models/transfer_progress.dart';

enum TransferDirection { sent, received }

class TransferQueueItem {
  const TransferQueueItem({
    required this.file,
    required this.status,
    this.bytesTransferred = 0,
    this.errorMessage,
    this.savedPath,
  });

  final TransferFile file;
  final TransferItemStatus status;
  final int bytesTransferred;
  final String? errorMessage;
  final String? savedPath;

  TransferQueueItem copyWith({
    TransferFile? file,
    TransferItemStatus? status,
    int? bytesTransferred,
    String? errorMessage,
    String? savedPath,
  }) {
    return TransferQueueItem(
      file: file ?? this.file,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
      savedPath: savedPath ?? this.savedPath,
    );
  }
}

class TransferHistoryEntry {
  const TransferHistoryEntry({
    required this.id,
    required this.peerName,
    required this.direction,
    required this.fileNames,
    required this.totalBytes,
    required this.durationMs,
    required this.timestamp,
    required this.success,
    this.savedPaths = const [],
  });

  final String id;
  final String peerName;
  final TransferDirection direction;
  final List<String> fileNames;
  final int totalBytes;
  final int durationMs;
  final DateTime timestamp;
  final bool success;
  final List<String> savedPaths;

  double get averageBytesPerSec =>
      durationMs > 0 ? (totalBytes * 1000.0) / durationMs : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerName': peerName,
        'direction': direction.name,
        'fileNames': fileNames,
        'totalBytes': totalBytes,
        'durationMs': durationMs,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'savedPaths': savedPaths,
      };

  factory TransferHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TransferHistoryEntry(
      id: json['id'] as String? ?? '',
      peerName: json['peerName'] as String? ?? 'Unknown',
      direction: (json['direction'] as String?) == 'received'
          ? TransferDirection.received
          : TransferDirection.sent,
      fileNames: List<String>.from(json['fileNames'] as List? ?? const []),
      totalBytes: json['totalBytes'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      success: json['success'] as bool? ?? false,
      savedPaths: List<String>.from(json['savedPaths'] as List? ?? const []),
    );
  }
}

class BenchmarkRecord {
  const BenchmarkRecord({
    required this.timestamp,
    required this.discoveryMs,
    required this.connectionMs,
    required this.transferDurationMs,
    required this.totalBytes,
    required this.averageBytesPerSec,
    required this.peakBytesPerSec,
    required this.success,
    required this.deviceModel,
    required this.androidSdk,
  });

  final DateTime timestamp;
  final int discoveryMs;
  final int connectionMs;
  final int transferDurationMs;
  final int totalBytes;
  final double averageBytesPerSec;
  final double peakBytesPerSec;
  final bool success;
  final String deviceModel;
  final int androidSdk;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'discoveryMs': discoveryMs,
        'connectionMs': connectionMs,
        'transferDurationMs': transferDurationMs,
        'totalBytes': totalBytes,
        'averageBytesPerSec': averageBytesPerSec,
        'peakBytesPerSec': peakBytesPerSec,
        'success': success,
        'deviceModel': deviceModel,
        'androidSdk': androidSdk,
      };

  factory BenchmarkRecord.fromJson(Map<String, dynamic> json) {
    return BenchmarkRecord(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      discoveryMs: json['discoveryMs'] as int? ?? 0,
      connectionMs: json['connectionMs'] as int? ?? 0,
      transferDurationMs: json['transferDurationMs'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      averageBytesPerSec: (json['averageBytesPerSec'] as num?)?.toDouble() ?? 0,
      peakBytesPerSec: (json['peakBytesPerSec'] as num?)?.toDouble() ?? 0,
      success: json['success'] as bool? ?? false,
      deviceModel: json['deviceModel'] as String? ?? 'Android',
      androidSdk: json['androidSdk'] as int? ?? 0,
    );
  }
}
