import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/core/theme/app_theme.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/models/transfer_session.dart';
import 'package:flashdrop/providers/transfer_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final historyAsync = ref.watch(transferHistoryProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: FlashDropGradients.primaryTile(brightness),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(Icons.bolt_rounded, color: scheme.onPrimary, size: 19),
            ),
            const SizedBox(width: 11),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.4),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'Transfer History',
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: FlashDropGradients.canvas(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                AppConstants.tagline,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'Direct offline Android-to-Android Wi-Fi transfer with SHA-256 verification.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _MonochromeActionTile(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Send',
                      subtitle: 'Find nearby phone',
                      gradient: FlashDropGradients.primaryTile(brightness),
                      foreground: scheme.onPrimary,
                      borderColor: scheme.outlineVariant,
                      onTap: () => context.push('/send'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MonochromeActionTile(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Receive',
                      subtitle: 'Wait for sender',
                      gradient: FlashDropGradients.secondaryTile(brightness),
                      foreground: scheme.onSurface,
                      borderColor: scheme.outlineVariant,
                      onTap: () => context.push('/receive'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/history'),
                    child: Text(
                      'See all',
                      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              historyAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: FlashDropGradients.cardSurface(brightness),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        'No transfers yet. Open FlashDrop on two nearby Android phones and choose Send or Receive.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: entries.take(4).map((entry) {
                      final isReceived = entry.direction == TransferDirection.received;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          gradient: FlashDropGradients.cardSurface(brightness),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              isReceived ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: scheme.onPrimaryContainer,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            entry.fileNames.length == 1
                                ? entry.fileNames.first
                                : '${entry.fileNames.length} files',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${entry.peerName} • ${FileSanitizer.formatBytes(entry.totalBytes)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Icon(
                            entry.success ? Icons.check_circle_outline : Icons.error_outline,
                            color: entry.success ? scheme.onSurface : scheme.error,
                            size: 20,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text('Unable to load history: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonochromeActionTile extends StatelessWidget {
  const _MonochromeActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.foreground,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final Color foreground;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: foreground),
                ),
                const SizedBox(height: 22),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
