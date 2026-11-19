enum DevicePlatform { android, ios, unknown }

enum TransportMode { nearby, wifiDirect }

enum PeerConnectionStatus {
  discovered,
  connecting,
  authenticating,
  connected,
  rejected,
  disconnected,
  failed,
}

class PeerDevice {
  const PeerDevice({
    required this.id,
    required this.name,
    this.platform = DevicePlatform.android,
    this.transport = TransportMode.nearby,
    this.status = PeerConnectionStatus.discovered,
    this.authToken,
    this.lastSeen,
  });

  final String id;
  final String name;
  final DevicePlatform platform;
  final TransportMode transport;
  final PeerConnectionStatus status;
  final String? authToken;
  final DateTime? lastSeen;

  PeerDevice copyWith({
    String? name,
    DevicePlatform? platform,
    TransportMode? transport,
    PeerConnectionStatus? status,
    String? authToken,
    DateTime? lastSeen,
  }) {
    return PeerDevice(
      id: id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      transport: transport ?? this.transport,
      status: status ?? this.status,
      authToken: authToken ?? this.authToken,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
