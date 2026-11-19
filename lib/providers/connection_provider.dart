import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/transport/peer_transport.dart';

class ConnectionStateModel {
  const ConnectionStateModel({
    this.activePeer,
    this.status = PeerConnectionStatus.disconnected,
    this.authToken,
    this.isIncoming = false,
    this.errorMessage,
    this.lastConnectionDurationMs = 0,
  });

  final PeerDevice? activePeer;
  final PeerConnectionStatus status;
  final String? authToken;
  final bool isIncoming;
  final String? errorMessage;
  final int lastConnectionDurationMs;

  bool get isConnected => status == PeerConnectionStatus.connected && activePeer != null;

  ConnectionStateModel copyWith({
    PeerDevice? activePeer,
    bool clearPeer = false,
    PeerConnectionStatus? status,
    String? authToken,
    bool clearToken = false,
    bool? isIncoming,
    String? errorMessage,
    bool clearError = false,
    int? lastConnectionDurationMs,
  }) {
    return ConnectionStateModel(
      activePeer: clearPeer ? null : (activePeer ?? this.activePeer),
      status: status ?? this.status,
      authToken: clearToken ? null : (authToken ?? this.authToken),
      isIncoming: isIncoming ?? this.isIncoming,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastConnectionDurationMs: lastConnectionDurationMs ?? this.lastConnectionDurationMs,
    );
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionStateModel>((ref) {
  return ConnectionNotifier(
    transport: ref.watch(peerTransportProvider),
    ref: ref,
  );
});

class ConnectionNotifier extends StateNotifier<ConnectionStateModel> {
  ConnectionNotifier({
    required PeerTransport transport,
    required Ref ref,
  })  : _transport = transport,
        _ref = ref,
        super(const ConnectionStateModel()) {
    _connSub = _transport.connectionEvents.listen(_onConnectionEvent);
  }

  final PeerTransport _transport;
  final Ref _ref;
  StreamSubscription<PeerConnectionEvent>? _connSub;
  Timer? _timeoutTimer;
  DateTime? _connectStartedAt;

  Future<void> requestConnection(PeerDevice device) async {
    final localName = _ref.read(deviceNameProvider);
    _connectStartedAt = DateTime.now();
    state = state.copyWith(
      activePeer: device,
      status: PeerConnectionStatus.connecting,
      isIncoming: false,
      clearError: true,
    );

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(AppConstants.connectionTimeout, () {
      if (state.status == PeerConnectionStatus.connecting) {
        state = state.copyWith(
          status: PeerConnectionStatus.failed,
          errorMessage: 'Connection timed out waiting for ${device.name}.',
        );
      }
    });

    try {
      await _transport.requestConnection(
        device.id,
        localDeviceName: localName,
        mode: device.transport,
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      state = state.copyWith(
        status: PeerConnectionStatus.failed,
        errorMessage: 'Failed to connect: $e',
      );
    }
  }

  Future<void> acceptConnection() async {
    final peer = state.activePeer;
    if (peer == null) return;
    await _transport.acceptConnection(peer.id);
  }

  Future<void> rejectConnection() async {
    final peer = state.activePeer;
    if (peer == null) return;
    await _transport.rejectConnection(peer.id);
    state = const ConnectionStateModel();
  }

  Future<void> disconnect() async {
    final peer = state.activePeer;
    await _transport.disconnect(peer?.id ?? '');
    state = const ConnectionStateModel();
  }

  void _onConnectionEvent(PeerConnectionEvent event) {
    _timeoutTimer?.cancel();
    final peer = PeerDevice(
      id: event.deviceId,
      name: event.deviceName ?? state.activePeer?.name ?? 'Nearby Phone',
      status: event.status,
      authToken: event.authToken,
    );

    if (event.status == PeerConnectionStatus.connected) {
      final elapsed = _connectStartedAt != null
          ? DateTime.now().difference(_connectStartedAt!).inMilliseconds
          : 0;
      state = state.copyWith(
        activePeer: peer,
        status: PeerConnectionStatus.connected,
        clearToken: true,
        clearError: true,
        lastConnectionDurationMs: elapsed,
      );
    } else if (event.status == PeerConnectionStatus.authenticating) {
      state = state.copyWith(
        activePeer: peer,
        status: PeerConnectionStatus.authenticating,
        authToken: event.authToken,
        isIncoming: event.isIncoming,
        clearError: true,
      );
    } else if (event.status == PeerConnectionStatus.disconnected ||
        event.status == PeerConnectionStatus.rejected ||
        event.status == PeerConnectionStatus.failed) {
      state = state.copyWith(
        status: event.status,
        errorMessage: event.error,
        clearToken: true,
      );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    unawaited(_connSub?.cancel());
    super.dispose();
  }
}
