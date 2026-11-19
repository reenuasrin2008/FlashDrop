import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/models/transfer_file.dart';
import 'package:flashdrop/models/transfer_progress.dart';
import 'package:flashdrop/models/transfer_session.dart';
import 'package:flashdrop/providers/connection_provider.dart';
import 'package:flashdrop/providers/discovery_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/services/file_service.dart';
import 'package:flashdrop/services/history_repository.dart';
import 'package:flashdrop/services/integrity_service.dart';
import 'package:flashdrop/transport/peer_transport.dart';

class TransferState {
  const TransferState({
    this.queue = const [],
    this.direction = TransferDirection.sent,
    this.activeProgress,
    this.isTransferring = false,
    this.isCompleted = false,
    this.startedAt,
    this.completedAt,
    this.peakSpeedBytesPerSec = 0,
    this.pendingIncoming,
    this.errorMessage,
  });

  final List<TransferQueueItem> queue;
  final TransferDirection direction;
  final TransferProgress? activeProgress;
  final bool isTransferring;
  final bool isCompleted;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double peakSpeedBytesPerSec;
  final IncomingTransferEvent? pendingIncoming;
  final String? errorMessage;

  int get totalBytes => queue.fold(0, (sum, item) => sum + item.file.sizeBytes);
  int get completedCount =>
      queue.where((item) => item.status == TransferItemStatus.completed).length;

  int get durationMs {
    if (startedAt == null) return 0;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!).inMilliseconds;
  }

  double get averageSpeedBytesPerSec =>
      durationMs > 0 ? (totalBytes * 1000.0) / durationMs : 0;

  TransferState copyWith({
    List<TransferQueueItem>? queue,
    TransferDirection? direction,
    TransferProgress? activeProgress,
    bool clearProgress = false,
    bool? isTransferring,
    bool? isCompleted,
    DateTime? startedAt,
    DateTime? completedAt,
    double? peakSpeedBytesPerSec,
    IncomingTransferEvent? pendingIncoming,
    bool clearPendingIncoming = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransferState(
      queue: queue ?? this.queue,
      direction: direction ?? this.direction,
      activeProgress: clearProgress ? null : (activeProgress ?? this.activeProgress),
      isTransferring: isTransferring ?? this.isTransferring,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      peakSpeedBytesPerSec: peakSpeedBytesPerSec ?? this.peakSpeedBytesPerSec,
      pendingIncoming:
          clearPendingIncoming ? null : (pendingIncoming ?? this.pendingIncoming),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  return TransferNotifier(
    transport: ref.watch(peerTransportProvider),
    integrity: ref.watch(integrityServiceProvider),
    fileService: ref.watch(fileServiceProvider),
    historyRepo: ref.watch(historyRepositoryProvider),
    ref: ref,
  );
});

final transferHistoryProvider = FutureProvider<List<TransferHistoryEntry>>((ref) {
  return ref.watch(historyRepositoryProvider).loadHistory();
});

final benchmarkHistoryProvider = FutureProvider<List<BenchmarkRecord>>((ref) {
  return ref.watch(historyRepositoryProvider).loadBenchmarks();
});

class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier({
    required PeerTransport transport,
    required IntegrityService integrity,
    required FileService fileService,
    required HistoryRepository historyRepo,
    required Ref ref,
  })  : _transport = transport,
        _integrity = integrity,
        _fileService = fileService,
        _historyRepo = historyRepo,
        _ref = ref,
        super(const TransferState()) {
    _progressSub = _transport.transferProgress.listen(_onProgress);
    _incomingSub = _transport.incomingTransfers.listen(_onIncomingMetadata);
    _verifiedSub = _transport.verifiedFiles.listen(_onVerifiedFile);
    _ackSub = _transport.transferAcks.listen(_onTransferAck);
  }

  static const _uuid = Uuid();
  final PeerTransport _transport;
  final IntegrityService _integrity;
  final FileService _fileService;
  final HistoryRepository _historyRepo;
  final Ref _ref;

  StreamSubscription<TransferProgress>? _progressSub;
  StreamSubscription<IncomingTransferEvent>? _incomingSub;
  StreamSubscription<VerifiedFileEvent>? _verifiedSub;
  StreamSubscription<TransferAckEvent>? _ackSub;

  Completer<TransferAckEvent>? _pendingAckCompleter;
  bool _cancelRequested = false;

  Future<void> pickFiles() async {
    final picked = await _fileService.pickFiles();
    if (picked.isEmpty) return;
    final items = picked
        .map((f) => TransferQueueItem(file: f, status: TransferItemStatus.waiting))
        .toList();
    state = state.copyWith(
      queue: [...state.queue, ...items],
      direction: TransferDirection.sent,
      isCompleted: false,
      clearError: true,
    );
  }

  void removeFile(String fileId) {
    if (state.isTransferring) return;
    state = state.copyWith(
      queue: state.queue.where((item) => item.file.id != fileId).toList(),
    );
  }

  void clearQueue() {
    if (state.isTransferring) return;
    state = const TransferState();
  }

  Future<void> startSendingQueue() async {
    final conn = _ref.read(connectionProvider);
    final peer = conn.activePeer;
    if (peer == null || !conn.isConnected || state.queue.isEmpty) {
      state = state.copyWith(errorMessage: 'Connect to a receiver and select files first.');
      return;
    }

    _cancelRequested = false;
    final start = DateTime.now();
    state = state.copyWith(
      isTransferring: true,
      isCompleted: false,
      startedAt: start,
      peakSpeedBytesPerSec: 0,
      clearError: true,
    );

    final totalFiles = state.queue.length;
    var allSucceeded = true;

    for (var i = 0; i < totalFiles; i++) {
      if (_cancelRequested) {
        allSucceeded = false;
        break;
      }

      final current = state.queue[i];
      if (current.status == TransferItemStatus.completed) continue;

      _updateItemStatus(current.file.id, TransferItemStatus.hashing);
      try {
        final checksum = await _integrity.computeSha256(current.file.path);
        final metadata = TransferMetadata(
          protocolVersion: AppConstants.protocolVersion,
          transferId: current.file.id,
          fileName: current.file.name,
          fileSize: current.file.sizeBytes,
          mimeType: current.file.mimeType,
          checksum: checksum,
          fileIndex: i + 1,
          totalFiles: totalFiles,
        );

        _updateItemStatus(current.file.id, TransferItemStatus.inProgress);
        await _transport.sendMetadata(peer.id, metadata);

        _pendingAckCompleter = Completer<TransferAckEvent>();
        await _transport.sendFile(
          peer.id,
          current.file.id,
          File(current.file.path),
          metadata: metadata,
          mode: peer.transport,
        );

        final ack = await _pendingAckCompleter!.future.timeout(
          const Duration(minutes: 30),
          onTimeout: () => TransferAckEvent(
            deviceId: peer.id,
            transferId: current.file.id,
            verified: false,
            error: 'Timed out waiting for integrity confirmation',
          ),
        );

        if (ack.verified) {
          _updateItemStatus(
            current.file.id,
            TransferItemStatus.completed,
            bytesTransferred: current.file.sizeBytes,
          );
        } else {
          allSucceeded = false;
          _updateItemStatus(
            current.file.id,
            TransferItemStatus.failed,
            errorMessage: ack.error ?? 'Receiver failed SHA-256 verification',
          );
        }
      } catch (e) {
        allSucceeded = false;
        _updateItemStatus(
          current.file.id,
          TransferItemStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }

    final end = DateTime.now();
    state = state.copyWith(
      isTransferring: false,
      isCompleted: allSucceeded && !_cancelRequested,
      completedAt: end,
    );

    await _recordSessionAndBenchmark(
      peerName: peer.name,
      direction: TransferDirection.sent,
      success: allSucceeded && !_cancelRequested,
    );
  }

  Future<void> retryFailed() async {
    final reset = state.queue
        .map((item) => item.status == TransferItemStatus.failed
            ? item.copyWith(status: TransferItemStatus.waiting, bytesTransferred: 0)
            : item)
        .toList();
    state = state.copyWith(queue: reset, clearError: true);
    await startSendingQueue();
  }

  Future<void> cancelActiveTransfer() async {
    _cancelRequested = true;
    final activeId = state.activeProgress?.transferId;
    if (activeId != null) {
      await _transport.cancelTransfer(activeId);
    }
    if (_pendingAckCompleter != null && !_pendingAckCompleter!.isCompleted) {
      _pendingAckCompleter!.complete(
        TransferAckEvent(
          deviceId: '',
          transferId: activeId ?? '',
          verified: false,
          error: 'Cancelled by user',
        ),
      );
    }
    state = state.copyWith(
      isTransferring: false,
      errorMessage: 'Transfer cancelled.',
    );
  }

  void _onIncomingMetadata(IncomingTransferEvent event) {
    final meta = event.metadata;
    final file = TransferFile(
      id: meta.transferId,
      name: meta.fileName,
      path: '',
      sizeBytes: meta.fileSize,
      mimeType: meta.mimeType,
      checksum: meta.checksum,
    );
    final updatedQueue = [
      ...state.queue,
      TransferQueueItem(file: file, status: TransferItemStatus.inProgress),
    ];
    state = state.copyWith(
      queue: updatedQueue,
      direction: TransferDirection.received,
      isTransferring: true,
      isCompleted: false,
      startedAt: state.startedAt ?? DateTime.now(),
      pendingIncoming: event,
      clearError: true,
    );
  }

  void _onProgress(TransferProgress progress) {
    final peak = progress.currentSpeedBytesPerSec > state.peakSpeedBytesPerSec
        ? progress.currentSpeedBytesPerSec
        : state.peakSpeedBytesPerSec;
    final updatedQueue = state.queue.map((item) {
      if (item.file.id != progress.transferId) return item;
      return item.copyWith(
        status: progress.status,
        bytesTransferred: progress.bytesTransferred,
        errorMessage: progress.errorMessage,
      );
    }).toList();

    state = state.copyWith(
      queue: updatedQueue,
      activeProgress: progress,
      peakSpeedBytesPerSec: peak,
      errorMessage: progress.status == TransferItemStatus.failed ? progress.errorMessage : null,
    );
  }

  Future<void> _onVerifiedFile(VerifiedFileEvent event) async {
    final updatedQueue = state.queue.map((item) {
      if (item.file.id != event.transferId) return item;
      return item.copyWith(
        status: TransferItemStatus.completed,
        bytesTransferred: event.fileSize,
        savedPath: event.savedPath,
      );
    }).toList();

    final allDone = updatedQueue.isNotEmpty &&
        updatedQueue.every((i) => i.status == TransferItemStatus.completed);

    state = state.copyWith(
      queue: updatedQueue,
      isTransferring: !allDone,
      isCompleted: allDone,
      completedAt: allDone ? DateTime.now() : null,
      clearPendingIncoming: allDone,
    );

    if (allDone) {
      final peerName = _ref.read(connectionProvider).activePeer?.name ?? 'Sender';
      await _recordSessionAndBenchmark(
        peerName: peerName,
        direction: TransferDirection.received,
        success: true,
      );
    }
  }

  void _onTransferAck(TransferAckEvent ack) {
    if (_pendingAckCompleter != null && !_pendingAckCompleter!.isCompleted) {
      _pendingAckCompleter!.complete(ack);
    }
  }

  void _updateItemStatus(
    String fileId,
    TransferItemStatus status, {
    int? bytesTransferred,
    String? errorMessage,
  }) {
    final updated = state.queue.map((item) {
      if (item.file.id != fileId) return item;
      return item.copyWith(
        status: status,
        bytesTransferred: bytesTransferred ?? item.bytesTransferred,
        errorMessage: errorMessage,
      );
    }).toList();
    state = state.copyWith(queue: updated);
  }

  Future<void> _recordSessionAndBenchmark({
    required String peerName,
    required TransferDirection direction,
    required bool success,
  }) async {
    final entry = TransferHistoryEntry(
      id: _uuid.v4(),
      peerName: peerName,
      direction: direction,
      fileNames: state.queue.map((i) => i.file.name).toList(),
      totalBytes: state.totalBytes,
      durationMs: state.durationMs,
      timestamp: DateTime.now(),
      success: success,
      savedPaths: state.queue
          .map((i) => i.savedPath ?? i.file.path)
          .where((p) => p.isNotEmpty)
          .toList(),
    );
    await _historyRepo.addHistoryEntry(entry);

    final discovery = _ref.read(discoveryProvider);
    final conn = _ref.read(connectionProvider);
    await _historyRepo.addBenchmark(
      BenchmarkRecord(
        timestamp: DateTime.now(),
        discoveryMs: discovery.lastDiscoveryDurationMs,
        connectionMs: conn.lastConnectionDurationMs,
        transferDurationMs: state.durationMs,
        totalBytes: state.totalBytes,
        averageBytesPerSec: state.averageSpeedBytesPerSec,
        peakBytesPerSec: state.peakSpeedBytesPerSec,
        success: success,
        deviceModel: discovery.adapterStatus?.deviceModel ?? 'Android',
        androidSdk: discovery.adapterStatus?.sdkInt ?? 0,
      ),
    );
    _ref.invalidate(transferHistoryProvider);
    _ref.invalidate(benchmarkHistoryProvider);
  }

  @override
  void dispose() {
    unawaited(_progressSub?.cancel());
    unawaited(_incomingSub?.cancel());
    unawaited(_verifiedSub?.cancel());
    unawaited(_ackSub?.cancel());
    super.dispose();
  }
}
