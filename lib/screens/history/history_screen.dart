import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/models/transfer_session.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/widgets/empty_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transferHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear history',
            onPressed: () async {
              await ref.read(historyRepositoryProvider).clearHistory();
              ref.invalidate(transferHistoryProvider);
            },
          ),
        ],
      ),
      body: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history_rounded,
              title: 'No transfer history',
              subtitle: 'Completed offline transfers appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (_, index) {
              final e = entries[index];
              final isReceived = e.direction == TransferDirection.received;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    isReceived ? Icons.download_done_rounded : Icons.upload_rounded,
                    color: isReceived ? scheme.secondary : scheme.primary,
                  ),
                  title: Text(e.fileNames.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${e.peerName} • ${FileSanitizer.formatBytes(e.totalBytes)} • '
                    '${FileSanitizer.formatSpeed(e.averageBytesPerSec)}',
                  ),
                  trailing: Icon(
                    e.success ? Icons.verified_rounded : Icons.error_outline_rounded,
                    color: e.success ? scheme.secondary : scheme.error,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading history: $e')),
      ),
    );
  }
}
