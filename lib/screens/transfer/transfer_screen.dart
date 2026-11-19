import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/models/transfer_progress.dart';
import 'package:flashdrop/models/transfer_session.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/widgets/progress_ring.dart';
import 'package:flashdrop/widgets/transfer_card.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfer = ref.watch(transferProvider);
    final progress = transfer.activeProgress;

    ref.listen<TransferState>(transferProvider, (prev, next) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        context.pushReplacement('/success');
      }
    });

    final isSending = transfer.direction == TransferDirection.sent;
    final hasFailed = transfer.queue.any((i) => i.status == TransferItemStatus.failed);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSending ? 'Sending Files' : 'Receiving Files'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: TransferProgressRing(
              fraction: progress?.fraction ?? 0,
              percentage: progress?.percentage ?? 0,
              speedLabel: FileSanitizer.formatSpeed(progress?.currentSpeedBytesPerSec ?? 0),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              progress != null
                  ? '${FileSanitizer.formatBytes(progress.bytesTransferred)} / ${FileSanitizer.formatBytes(progress.totalBytes)}'
                  : 'Preparing transfer...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (progress?.estimatedRemaining != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Estimated remaining: ${FileSanitizer.formatDuration(progress!.estimatedRemaining!)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (transfer.isTransferring)
                OutlinedButton.icon(
                  onPressed: () => ref.read(transferProvider.notifier).cancelActiveTransfer(),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                ),
              if (hasFailed && !transfer.isTransferring && isSending) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => ref.read(transferProvider.notifier).retryFailed(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Failed'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Transfer Queue (${transfer.completedCount} / ${transfer.queue.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...transfer.queue.map((item) => TransferQueueCard(item: item)),
        ],
      ),
    );
  }
}
