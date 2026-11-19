import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/widgets/empty_state.dart';

class BenchmarkScreen extends ConsumerWidget {
  const BenchmarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benchAsync = ref.watch(benchmarkHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measured Benchmarks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear logs',
            onPressed: () async {
              await ref.read(historyRepositoryProvider).clearBenchmarks();
              ref.invalidate(benchmarkHistoryProvider);
            },
          ),
        ],
      ),
      body: benchAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const EmptyStateView(
              icon: Icons.speed_rounded,
              title: 'No benchmark data yet',
              subtitle: 'Complete a real transfer between two Android phones to record measured throughput.',
            );
          }
          final failedCount = records.where((r) => !r.success).length;
          final failureRate = ((failedCount / records.length) * 100).toStringAsFixed(1);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text('Recorded Runs: ${records.length}'),
                  subtitle: Text('Failure Rate: $failureRate%'),
                ),
              ),
              const SizedBox(height: 12),
              ...records.map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      '${FileSanitizer.formatBytes(r.totalBytes)} • Avg ${FileSanitizer.formatSpeed(r.averageBytesPerSec)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Peak: ${FileSanitizer.formatSpeed(r.peakBytesPerSec)} • '
                      'Disc: ${r.discoveryMs}ms • Conn: ${r.connectionMs}ms • '
                      '${r.deviceModel} (API ${r.androidSdk})',
                    ),
                    trailing: Icon(
                      r.success ? Icons.check_circle_outline : Icons.error_outline,
                      color: r.success
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load benchmarks: $e')),
      ),
    );
  }
}
