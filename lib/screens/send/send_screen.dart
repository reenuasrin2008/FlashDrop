import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/core/theme/app_theme.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/providers/connection_provider.dart';
import 'package:flashdrop/providers/discovery_provider.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/widgets/device_card.dart';
import 'package:flashdrop/widgets/empty_state.dart';
import 'package:flashdrop/widgets/pulse_radar.dart';
import 'package:flashdrop/widgets/transfer_card.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  DiscoveryNotifier? _discoveryNotifier;

  @override
  void initState() {
    super.initState();
    _discoveryNotifier = ref.read(discoveryProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_discoveryNotifier?.startDiscovery());
    });
  }

  @override
  void dispose() {
    unawaited(_discoveryNotifier?.stopDiscovery());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);
    final connection = ref.watch(connectionProvider);
    final transfer = ref.watch(transferProvider);
    final brightness = Theme.of(context).brightness;

    ref.listen<ConnectionStateModel>(connectionProvider, (prev, next) {
      if (next.status == PeerConnectionStatus.authenticating &&
          prev?.status != PeerConnectionStatus.authenticating) {
        context.push('/connection');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        actions: [
          IconButton(
            icon: Icon(discovery.isDiscovering ? Icons.stop_circle_outlined : Icons.refresh_rounded),
            tooltip: discovery.isDiscovering ? 'Stop scanning' : 'Scan again',
            onPressed: () {
              final notifier = ref.read(discoveryProvider.notifier);
              if (discovery.isDiscovering) {
                unawaited(notifier.stopDiscovery());
              } else {
                unawaited(notifier.startDiscovery());
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: FlashDropGradients.canvas(brightness)),
        child: Column(
          children: [
            if (discovery.errorMessage != null)
              MaterialBanner(
                content: Text(discovery.errorMessage!),
                actions: [
                  if (discovery.permissionPermanentlyDenied)
                    TextButton(
                      onPressed: () => unawaited(ref.read(permissionManagerProvider).openSettings()),
                      child: const Text('Settings'),
                    ),
                  TextButton(
                    onPressed: () => unawaited(ref.read(discoveryProvider.notifier).startDiscovery()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (discovery.isDiscovering)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    'Selected Files (${transfer.queue.length} • ${FileSanitizer.formatBytes(transfer.totalBytes)})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(ref.read(transferProvider.notifier).pickFiles()),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Choose Files'),
                  ),
                  const SizedBox(height: 10),
                  ...transfer.queue.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransferQueueCard(
                        item: item,
                        onRemove: () => ref.read(transferProvider.notifier).removeFile(item.file.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    connection.isConnected
                        ? 'Connected to ${connection.activePeer!.name}'
                        : 'Nearby Receivers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (connection.isConnected)
                    FilledButton.icon(
                      onPressed: transfer.queue.isEmpty
                          ? null
                          : () {
                              unawaited(ref.read(transferProvider.notifier).startSendingQueue());
                              context.push('/transfer');
                            },
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text('Send ${transfer.queue.length} File(s)'),
                    )
                  else if (discovery.devices.isEmpty)
                    Column(
                      children: [
                        if (discovery.isDiscovering)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: PulseRadar(icon: Icons.radar_rounded, active: true, size: 132),
                          ),
                        EmptyStateView(
                          icon: discovery.isDiscovering ? Icons.sensors_rounded : Icons.radar_rounded,
                          title: discovery.isDiscovering
                              ? 'Scanning for nearby phones...'
                              : 'No receivers found',
                          subtitle: 'Open FlashDrop on the receiving Android phone and tap Receive.',
                          actionLabel: discovery.isDiscovering ? null : 'Scan Again',
                          onAction: () =>
                              unawaited(ref.read(discoveryProvider.notifier).startDiscovery()),
                        ),
                      ],
                    )
                  else
                    ...discovery.devices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DeviceCard(
                          device: device,
                          onTap: () => unawaited(
                            ref.read(connectionProvider.notifier).requestConnection(device),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
