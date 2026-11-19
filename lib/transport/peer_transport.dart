import 'dart:io';

import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/models/transfer_file.dart';
import 'package:flashdrop/models/transfer_progress.dart';

class AdapterStatus {
  const AdapterStatus({
    required this.bluetoothEnabled,
    required this.wifiEnabled,
    required this.deviceModel,
    required this.sdkInt,
  });

  final bool bluetoothEnabled;
  final bool wifiEnabled;
  final String deviceModel;
  final int sdkInt;
}

class PeerConnectionEvent {
  const PeerConnectionEvent({
    required this.deviceId,
    required this.status,
    this.deviceName,
    this.authToken,
    this.isIncoming = false,
    this.error,
  });

  final String deviceId;
  final PeerConnectionStatus status;
  final String? deviceName;
  final String? authToken;
  final bool isIncoming;
  final String? error;
}

class IncomingTransferEvent {
  const IncomingTransferEvent({
    required this.deviceId,
    required this.metadata,
  });

  final String deviceId;
  final TransferMetadata metadata;
}

class VerifiedFileEvent {
  const VerifiedFileEvent({
    required this.transferId,
    required this.deviceId,
    required this.fileName,
    required this.savedPath,
    required this.fileSize,
    required this.checksum,
  });

  final String transferId;
  final String deviceId;
  final String fileName;
  final String savedPath;
  final int fileSize;
  final String checksum;
}

class TransferAckEvent {
  const TransferAckEvent({
    required this.deviceId,
    required this.transferId,
    required this.verified,
    this.error,
  });

  final String deviceId;
  final String transferId;
  final bool verified;
  final String? error;
}

abstract class PeerTransport {
  Future<AdapterStatus> initialize({bool enableWifiDirectFallback = false});

  Future<AdapterStatus> checkAdapters();

  Future<void> startAdvertising(String deviceName);

  Future<void> stopAdvertising();

  Future<void> startDiscovery({TransportMode mode = TransportMode.nearby});

  Future<void> stopDiscovery();

  Future<void> requestConnection(
    String deviceId, {
    required String localDeviceName,
    TransportMode mode = TransportMode.nearby,
  });

  Future<void> acceptConnection(String deviceId);

  Future<void> rejectConnection(String deviceId);

  Future<void> sendMetadata(String deviceId, TransferMetadata metadata);

  Future<void> sendFile(
    String deviceId,
    String transferId,
    File file, {
    TransferMetadata? metadata,
    TransportMode mode = TransportMode.nearby,
  });

  Future<void> cancelTransfer(String transferId);

  Future<void> disconnect(String deviceId);

  Stream<PeerDevice> get discoveredDevices;

  Stream<String> get lostDevices;

  Stream<PeerConnectionEvent> get connectionEvents;

  Stream<TransferProgress> get transferProgress;

  Stream<IncomingTransferEvent> get incomingTransfers;

  Stream<VerifiedFileEvent> get verifiedFiles;

  Stream<TransferAckEvent> get transferAcks;

  void dispose();
}
