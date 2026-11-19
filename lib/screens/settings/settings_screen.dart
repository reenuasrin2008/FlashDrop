import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/providers/transfer_provider.dart';
import 'package:flashdrop/providers/transport_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = ref.watch(deviceNameProvider);
    final themeMode = ref.watch(themeModeProvider);
    final transportMode = ref.watch(preferredTransportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Device Name'),
              subtitle: Text(deviceName),
              onTap: () => _editDeviceName(context, ref, deviceName),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_tethering_rounded),
              title: const Text('Android Transport Mode'),
              subtitle: Text(
                transportMode == TransportMode.nearby
                    ? 'Nearby Connections (Recommended — auto Wi-Fi upgrade)'
                    : 'Wi-Fi Direct Fallback (Android-to-Android TCP)',
              ),
              trailing: DropdownButton<TransportMode>(
                value: transportMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: TransportMode.nearby, child: Text('Nearby')),
                  DropdownMenuItem(value: TransportMode.wifiDirect, child: Text('Wi-Fi Direct')),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(preferredTransportProvider.notifier).state = mode;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Appearance'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (mode) {
                  if (mode != null) ref.read(themeModeProvider.notifier).state = mode;
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('Performance Benchmarks'),
              subtitle: const Text('Inspect measured discovery, connection, and throughput logs'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/benchmark'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
              title: const Text('Clear Transfer History'),
              onTap: () async {
                await ref.read(historyRepositoryProvider).clearHistory();
                ref.invalidate(transferHistoryProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transfer history cleared')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDeviceName(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Visible to nearby devices'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated != null && updated.trim().isNotEmpty) {
      await ref.read(deviceNameProvider.notifier).updateName(updated);
    }
  }
}
