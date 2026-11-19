import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/models/transfer_file.dart';
import 'package:flashdrop/models/transfer_progress.dart';
import 'package:flashdrop/transport/peer_transport.dart';

class NearbyTransport implements PeerTransport {
  NearbyTransport({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel(AppConstants.methodChannelName),
        _eventChannel = eventChannel ?? const EventChannel(AppConstants.eventChannelName) {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(_handleNativeEvent);
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;

  final _discoveredController = StreamController<PeerDevice>.broadcast();
  final _lostController = StreamController<String>.broadcast();
  final _connectionController = StreamController<PeerConnectionEvent>.broadcast();
  final _progressController = StreamController<TransferProgress>.broadcast();
  final _incomingController = StreamController<IncomingTransferEvent>.broadcast();
  final _verifiedController = StreamController<VerifiedFileEvent>.broadcast();
  final _ackController = StreamController<TransferAckEvent>.broadcast();

  final Map<String, DateTime> _transferStartTimes = {};
  final Map<String, int> _lastSampleBytes = {};
  final Map<String, DateTime> _lastSampleTimes = {};

  @override
  Stream<PeerDevice> get discoveredDevices => _discoveredController.stream;

  @override
  Stream<String> get lostDevices => _lostController.stream;

  @override
  Stream<PeerConnectionEvent> get connectionEvents => _connectionController.stream;

  @override
  Stream<TransferProgress> get transferProgress => _progressController.stream;

  @override
  Stream<IncomingTransferEvent> get incomingTransfers => _incomingController.stream;

  @override
  Stream<VerifiedFileEvent> get verifiedFiles => _verifiedController.stream;

  @override
  Stream<TransferAckEvent> get transferAcks => _ackController.stream;

  @override
  Future<AdapterStatus> initialize({bool enableWifiDirectFallback = false}) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'initialize',
      {'enableWifiDirectFallback': enableWifiDirectFallback},
    );
    return _parseAdapterStatus(result);
  }

  @override
  Future<AdapterStatus> checkAdapters() async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>('checkAdapters');
    return _parseAdapterStatus(result);
  }

  AdapterStatus _parseAdapterStatus(Map<String, dynamic>? map) {
    return AdapterStatus(
      bluetoothEnabled: map?['bluetoothEnabled'] as bool? ?? false,
      wifiEnabled: map?['wifiEnabled'] as bool? ?? false,
      deviceModel: map?['deviceModel'] as String? ?? 'Android Device',
      sdkInt: map?['sdkInt'] as int? ?? 34,
    );
  }

  @override
  Future<void> startAdvertising(String deviceName) async {
    await _methodChannel.invokeMethod('startAdvertising', {'deviceName': deviceName});
  }

  @override
  Future<void> stopAdvertising() async {
    await _methodChannel.invokeMethod('stopAdvertising');
  }

  @override
  Future<void> startDiscovery({TransportMode mode = TransportMode.nearby}) async {
    await _methodChannel.invokeMethod('startDiscovery', {'transport': mode.name});
  }

  @override
  Future<void> stopDiscovery() async {
    await _methodChannel.invokeMethod('stopDiscovery');
  }

  @override
  Future<void> requestConnection(
    String deviceId, {
    required String localDeviceName,
    TransportMode mode = TransportMode.nearby,
  }) async {
    await _methodChannel.invokeMethod('requestConnection', {
      'deviceId': deviceId,
      'localDeviceName': localDeviceName,
      'transport': mode.name,
    });
  }

  @override
  Future<void> acceptConnection(String deviceId) async {
    await _methodChannel.invokeMethod('acceptConnection', {'deviceId': deviceId});
  }

  @override
  Future<void> rejectConnection(String deviceId) async {
    await _methodChannel.invokeMethod('rejectConnection', {'deviceId': deviceId});
  }

  @override
  Future<void> sendMetadata(String deviceId, TransferMetadata metadata) async {
    await _methodChannel.invokeMethod('sendMetadata', {
      'deviceId': deviceId,
      'metadataJson': metadata.toJsonString(),
    });
  }

  @override
  Future<void> sendFile(
    String deviceId,
    String transferId,
    File file, {
    TransferMetadata? metadata,
    TransportMode mode = TransportMode.nearby,
  }) async {
    _transferStartTimes[transferId] = DateTime.now();
    await _methodChannel.invokeMethod('sendFile', {
      'deviceId': deviceId,
      'transferId': transferId,
      'filePath': file.path,
      'transport': mode.name,
      if (metadata != null) 'metadataJson': metadata.toJsonString(),
    });
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    await _methodChannel.invokeMethod('cancelTransfer', {'transferId': transferId});
    _clearTransferTiming(transferId);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _methodChannel.invokeMethod('disconnect', {'deviceId': deviceId});
  }

  void _handleNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type'] as String? ?? '';

    switch (type) {
      case 'deviceFound':
        _discoveredController.add(
          PeerDevice(
            id: map['deviceId'] as String? ?? '',
            name: map['deviceName'] as String? ?? 'Nearby Phone',
            platform: (map['platform'] as String?) == 'ios'
                ? DevicePlatform.ios
                : DevicePlatform.android,
            transport: (map['transport'] as String?) == 'wifiDirect'
                ? TransportMode.wifiDirect
                : TransportMode.nearby,
            lastSeen: DateTime.now(),
          ),
        );
        break;

      case 'deviceLost':
        final deviceId = map['deviceId'] as String? ?? '';
        if (deviceId.isNotEmpty) _lostController.add(deviceId);
        break;

      case 'connectionState':
        _connectionController.add(
          PeerConnectionEvent(
            deviceId: map['deviceId'] as String? ?? '',
            deviceName: map['deviceName'] as String?,
            status: _parseConnectionStatus(map['status'] as String? ?? ''),
            authToken: map['authToken'] as String?,
            isIncoming: map['isIncoming'] as bool? ?? false,
            error: map['error'] as String?,
          ),
        );
        break;

      case 'incomingMetadata':
        try {
          final metadata = TransferMetadata.fromJson({
            'protocolVersion': AppConstants.protocolVersion,
            'transferId': map['transferId'],
            'fileName': map['fileName'],
            'fileSize': map['fileSize'],
            'mimeType': map['mimeType'],
            'checksum': map['checksum'],
            'fileIndex': map['fileIndex'],
            'totalFiles': map['totalFiles'],
          });
          _transferStartTimes[metadata.transferId] = DateTime.now();
          _incomingController.add(
            IncomingTransferEvent(
              deviceId: map['deviceId'] as String? ?? '',
              metadata: metadata,
            ),
          );
        } catch (_) {
          // Invalid metadata is rejected safely
        }
        break;

      case 'transferProgress':
        final transferId = map['transferId'] as String? ?? '';
        final transferred = (map['bytesTransferred'] as num?)?.toInt() ?? 0;
        final total = (map['totalBytes'] as num?)?.toInt() ?? 0;
        final status = _parseTransferStatus(map['status'] as String? ?? '');
        final now = DateTime.now();
        final startedAt = _transferStartTimes.putIfAbsent(transferId, () => now);

        final progress = TransferProgress.compute(
          transferId: transferId,
          bytesTransferred: transferred,
          totalBytes: total,
          status: status,
          startedAt: startedAt,
          now: now,
          previousBytes: _lastSampleBytes[transferId],
          previousSampleTime: _lastSampleTimes[transferId],
          errorMessage: map['error'] as String?,
        );
        _lastSampleBytes[transferId] = transferred;
        _lastSampleTimes[transferId] = now;

        if (status == TransferItemStatus.completed ||
            status == TransferItemStatus.failed ||
            status == TransferItemStatus.cancelled) {
          _clearTransferTiming(transferId);
        }
        _progressController.add(progress);
        break;

      case 'incomingFileVerified':
        final transferId = map['transferId'] as String? ?? '';
        _clearTransferTiming(transferId);
        _verifiedController.add(
          VerifiedFileEvent(
            transferId: transferId,
            deviceId: map['deviceId'] as String? ?? '',
            fileName: map['fileName'] as String? ?? '',
            savedPath: map['savedPath'] as String? ?? '',
            fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
            checksum: map['checksum'] as String? ?? '',
          ),
        );
        break;

      case 'transferAck':
        _ackController.add(
          TransferAckEvent(
            deviceId: map['deviceId'] as String? ?? '',
            transferId: map['transferId'] as String? ?? '',
            verified: map['verified'] as bool? ?? false,
            error: map['error'] as String?,
          ),
        );
        break;

      case 'transferError':
        _progressController.add(
          TransferProgress(
            transferId: map['transferId'] as String? ?? '',
            bytesTransferred: 0,
            totalBytes: 0,
            status: TransferItemStatus.failed,
            errorMessage: map['error'] as String? ?? 'Transfer error',
          ),
        );
        break;
    }
  }

  PeerConnectionStatus _parseConnectionStatus(String raw) {
    switch (raw) {
      case 'connecting':
        return PeerConnectionStatus.connecting;
      case 'authenticating':
        return PeerConnectionStatus.authenticating;
      case 'connected':
        return PeerConnectionStatus.connected;
      case 'rejected':
        return PeerConnectionStatus.rejected;
      case 'disconnected':
        return PeerConnectionStatus.disconnected;
      case 'failed':
        return PeerConnectionStatus.failed;
      default:
        return PeerConnectionStatus.discovered;
    }
  }

  TransferItemStatus _parseTransferStatus(String raw) {
    switch (raw) {
      case 'inProgress':
        return TransferItemStatus.inProgress;
      case 'completed':
        return TransferItemStatus.completed;
      case 'failed':
        return TransferItemStatus.failed;
      case 'cancelled':
        return TransferItemStatus.cancelled;
      default:
        return TransferItemStatus.waiting;
    }
  }

  void _clearTransferTiming(String transferId) {
    _transferStartTimes.remove(transferId);
    _lastSampleBytes.remove(transferId);
    _lastSampleTimes.remove(transferId);
  }

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    unawaited(_discoveredController.close());
    unawaited(_lostController.close());
    unawaited(_connectionController.close());
    unawaited(_progressController.close());
    unawaited(_incomingController.close());
    unawaited(_verifiedController.close());
    unawaited(_ackController.close());
  }
}
