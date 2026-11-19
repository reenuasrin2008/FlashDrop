import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/core/theme/app_theme.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/providers/connection_provider.dart';
import 'package:flashdrop/providers/discovery_provider.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/widgets/fade_slide_in.dart';
import 'package:flashdrop/widgets/pulse_radar.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  DiscoveryNotifier? _discoveryNotifier;

  @override
  void initState() {
    super.initState();
    _discoveryNotifier = ref.read(discoveryProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_discoveryNotifier?.startAdvertising());
    });
  }

  @override
  void dispose() {
    unawaited(_discoveryNotifier?.stopAdvertising());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);
    final connection = ref.watch(connectionProvider);
    final deviceName = ref.watch(deviceNameProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ref.listen<TransferState>(transferProvider, (prev, next) {
      if (next.isTransferring && !(prev?.isTransferring ?? false)) {
        context.push('/transfer');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Files')),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: FlashDropGradients.canvas(theme.brightness)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulseRadar(
                icon: Icons.wifi_tethering_rounded,
                active: discovery.isAdvertising && !connection.isConnected,
                size: 164,
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                child: Text(
                  discovery.isAdvertising ? 'Visible as "$deviceName"' : 'Preparing receiver...',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delayMs: 70,
                child: Text(
                  discovery.errorMessage ??
                      'Keep this screen open. Incoming connections always require your approval.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: connection.status == PeerConnectionStatus.authenticating &&
                        connection.activePeer != null
                    ? Card(
                        key: const ValueKey('incoming_request'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text('Connection Request', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text('${connection.activePeer!.name} wants to send files.'),
                              if (connection.authToken != null) ...[
                                const SizedBox(height: 14),
                                Chip(
                                  label: Text(
                                    'Code: ${connection.authToken}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => unawaited(
                                        ref.read(connectionProvider.notifier).rejectConnection(),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => unawaited(
                                        ref.read(connectionProvider.notifier).acceptConnection(),
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : connection.isConnected
                        ? Card(
                            key: const ValueKey('connected_card'),
                            child: ListTile(
                              leading: Icon(Icons.verified_user_outlined, color: scheme.onSurface),
                              title: Text('Connected to ${connection.activePeer!.name}'),
                              subtitle: const Text('Waiting for sender to start transfer...'),
                              trailing: TextButton(
                                onPressed: () =>
                                    unawaited(ref.read(connectionProvider.notifier).disconnect()),
                                child: const Text('Disconnect'),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('idle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
