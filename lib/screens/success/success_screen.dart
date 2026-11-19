import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/core/theme/app_theme.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/widgets/fade_slide_in.dart';
import 'package:flashdrop/widgets/transfer_card.dart';

class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfer = ref.watch(transferProvider);
    final fileService = ref.read(fileServiceProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Complete')),
      body: Container(
        decoration: BoxDecoration(gradient: FlashDropGradients.canvas(theme.brightness)),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.72, end: 1.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: FlashDropGradients.primaryTile(theme.brightness),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(Icons.check_rounded, size: 42, color: scheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              child: Text(
                'All Files Verified (SHA-256)',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delayMs: 80,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: FlashDropGradients.cardSurface(theme.brightness),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCol(label: 'Size', value: FileSanitizer.formatBytes(transfer.totalBytes)),
                    _StatCol(
                      label: 'Duration',
                      value: FileSanitizer.formatDuration(
                        Duration(milliseconds: transfer.durationMs),
                      ),
                    ),
                    _StatCol(
                      label: 'Avg Speed',
                      value: FileSanitizer.formatSpeed(transfer.averageSpeedBytesPerSec),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ...transfer.queue.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TransferQueueCard(
                  item: item,
                  onOpen: (item.savedPath ?? item.file.path).isNotEmpty
                      ? () => unawaited(fileService.openFile(item.savedPath ?? item.file.path))
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(transferProvider.notifier).clearQueue();
                context.go('/');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
