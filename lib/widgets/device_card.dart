import 'package:flutter/material.dart';
import 'package:flashdrop/models/peer_device.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  final PeerDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transportLabel =
        device.transport == TransportMode.wifiDirect ? 'Wi-Fi Direct' : 'Nearby P2P';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.smartphone_rounded, color: scheme.onPrimaryContainer),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Android • $transportLabel • ${device.status.name}'),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: const Text('Connect'),
        ),
      ),
    );
  }
}
