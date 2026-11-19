import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/core/theme/app_theme.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/providers/connection_provider.dart';
import 'package:flashdrop/widgets/fade_slide_in.dart';
import 'package:flashdrop/widgets/pulse_radar.dart';

class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ref.listen<ConnectionStateModel>(connectionProvider, (prev, next) {
      if (next.isConnected && !(prev?.isConnected ?? false)) {
        if (context.canPop()) context.pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Connection')),
      body: Container(
        decoration: BoxDecoration(gradient: FlashDropGradients.canvas(theme.brightness)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: PulseRadar(
                icon: Icons.verified_user_outlined,
                active: conn.status == PeerConnectionStatus.connecting ||
                    conn.status == PeerConnectionStatus.authenticating,
                size: 148,
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              child: Text(
                conn.activePeer?.name ?? 'Nearby Device',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              conn.authToken != null
                  ? 'Confirm that this verification code matches on both phones:'
                  : 'Establishing secure peer-to-peer connection...',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (conn.authToken != null) ...[
              const SizedBox(height: 20),
              FadeSlideIn(
                delayMs: 80,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: FlashDropGradients.secondaryTile(theme.brightness),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      conn.authToken!,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (conn.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                conn.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 32),
            if (conn.status == PeerConnectionStatus.authenticating)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        unawaited(ref.read(connectionProvider.notifier).rejectConnection());
                        if (context.canPop()) context.pop();
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          unawaited(ref.read(connectionProvider.notifier).acceptConnection()),
                      child: const Text('Confirm & Connect'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
