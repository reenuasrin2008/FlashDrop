import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/core/permissions/permission_manager.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/transport/peer_transport.dart';

class DiscoveryState {
  const DiscoveryState({
    this.isDiscovering = false,
    this.isAdvertising = false,
    this.devices = const [],
    this.adapterStatus,
    this.errorMessage,
    this.permissionPermanentlyDenied = false,
    this.lastDiscoveryDurationMs = 0,
  });

  final bool isDiscovering;
  final bool isAdvertising;
  final List<PeerDevice> devices;
  final AdapterStatus? adapterStatus;
  final String? errorMessage;
  final bool permissionPermanentlyDenied;
  final int lastDiscoveryDurationMs;

  DiscoveryState copyWith({
    bool? isDiscovering,
    bool? isAdvertising,
    List<PeerDevice>? devices,
    AdapterStatus? adapterStatus,
    String? errorMessage,
    bool clearError = false,
    bool? permissionPermanentlyDenied,
    int? lastDiscoveryDurationMs,
  }) {
    return DiscoveryState(
      isDiscovering: isDiscovering ?? this.isDiscovering,
      isAdvertising: isAdvertising ?? this.isAdvertising,
      devices: devices ?? this.devices,
      adapterStatus: adapterStatus ?? this.adapterStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      permissionPermanentlyDenied:
          permissionPermanentlyDenied ?? this.permissionPermanentlyDenied,
      lastDiscoveryDurationMs: lastDiscoveryDurationMs ?? this.lastDiscoveryDurationMs,
    );
  }
}

final discoveryProvider = StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier(
    transport: ref.watch(peerTransportProvider),
    permissions: ref.watch(permissionManagerProvider),
    ref: ref,
  );
});

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier({
    required PeerTransport transport,
    required PermissionManager permissions,
    required Ref ref,
  })  : _transport = transport,
        _permissions = permissions,
        _ref = ref,
        super(const DiscoveryState()) {
    _foundSub = _transport.discoveredDevices.listen(_onDeviceFound);
    _lostSub = _transport.lostDevices.listen(_onDeviceLost);
  }

  final PeerTransport _transport;
  final PermissionManager _permissions;
  final Ref _ref;
  StreamSubscription<PeerDevice>? _foundSub;
  StreamSubscription<String>? _lostSub;
  Timer? _timeoutTimer;
  DateTime? _discoveryStartedAt;

  Future<bool> _ensureReady() async {
    final mode = _ref.read(preferredTransportProvider);
    final adapters = await _transport.initialize(
      enableWifiDirectFallback: mode == TransportMode.wifiDirect,
    );
    state = state.copyWith(adapterStatus: adapters, clearError: true);

    final permResult = await _permissions.requestTransferPermissions(
      androidSdkInt: adapters.sdkInt,
    );
    if (!permResult.granted) {
      state = state.copyWith(
        errorMessage: 'Required permissions missing: ${permResult.missingDescriptions.join(", ")}',
        permissionPermanentlyDenied: permResult.permanentlyDenied,
      );
      return false;
    }

    if (!adapters.wifiEnabled && !adapters.bluetoothEnabled) {
      state = state.copyWith(
        errorMessage: 'Turn on Wi-Fi or Bluetooth in Android settings to discover nearby phones.',
      );
      return false;
    }
    return true;
  }

  Future<void> startDiscovery() async {
    if (state.isDiscovering) return;
    if (!await _ensureReady()) return;

    try {
      final mode = _ref.read(preferredTransportProvider);
      _discoveryStartedAt = DateTime.now();
      state = state.copyWith(isDiscovering: true, devices: const [], clearError: true);
      await _transport.startDiscovery(mode: mode);

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(AppConstants.discoveryTimeout, () {
        if (state.isDiscovering && state.devices.isEmpty) {
          unawaited(stopDiscovery());
          state = state.copyWith(
            errorMessage: 'No nearby FlashDrop devices found. Ask the receiver to open Receive.',
          );
        }
      });
    } catch (e) {
      state = state.copyWith(isDiscovering: false, errorMessage: 'Discovery error: $e');
    }
  }

  Future<void> stopDiscovery() async {
    _timeoutTimer?.cancel();
    await _transport.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  Future<void> startAdvertising() async {
    if (state.isAdvertising) return;
    if (!await _ensureReady()) return;

    try {
      final name = _ref.read(deviceNameProvider);
      await _transport.startAdvertising(name);
      state = state.copyWith(isAdvertising: true, clearError: true);
    } catch (e) {
      state = state.copyWith(isAdvertising: false, errorMessage: 'Advertising error: $e');
    }
  }

  Future<void> stopAdvertising() async {
    await _transport.stopAdvertising();
    state = state.copyWith(isAdvertising: false);
  }

  void _onDeviceFound(PeerDevice device) {
    final existingIndex = state.devices.indexWhere((d) => d.id == device.id);
    final updated = List<PeerDevice>.from(state.devices);
    if (existingIndex >= 0) {
      updated[existingIndex] = device;
    } else {
      updated.add(device);
    }
    final elapsedMs = _discoveryStartedAt != null
        ? DateTime.now().difference(_discoveryStartedAt!).inMilliseconds
        : state.lastDiscoveryDurationMs;
    state = state.copyWith(
      devices: updated,
      lastDiscoveryDurationMs: state.devices.isEmpty ? elapsedMs : state.lastDiscoveryDurationMs,
    );
  }

  void _onDeviceLost(String deviceId) {
    final updated = state.devices.where((d) => d.id != deviceId).toList();
    state = state.copyWith(devices: updated);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    unawaited(_foundSub?.cancel());
    unawaited(_lostSub?.cancel());
    super.dispose();
  }
}
