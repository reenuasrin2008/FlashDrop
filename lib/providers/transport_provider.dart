import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashdrop/core/permissions/permission_manager.dart';
import 'package:flashdrop/models/peer_device.dart';
import 'package:flashdrop/services/file_service.dart';
import 'package:flashdrop/services/history_repository.dart';
import 'package:flashdrop/services/integrity_service.dart';
import 'package:flashdrop/transport/peer_transport.dart';
import 'package:flashdrop/transport/transport_factory.dart';

final peerTransportProvider = Provider<PeerTransport>((ref) {
  final transport = TransportFactory.createDefault();
  ref.onDispose(transport.dispose);
  return transport;
});

final permissionManagerProvider = Provider<PermissionManager>((_) => PermissionManager());
final integrityServiceProvider = Provider<IntegrityService>((_) => IntegrityService());
final fileServiceProvider = Provider<FileService>((_) => FileService());
final historyRepositoryProvider = Provider<HistoryRepository>((_) => HistoryRepository());

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);
final preferredTransportProvider = StateProvider<TransportMode>((_) => TransportMode.nearby);

final deviceNameProvider = StateNotifierProvider<DeviceNameNotifier, String>((ref) {
  return DeviceNameNotifier(ref.watch(historyRepositoryProvider));
});

class DeviceNameNotifier extends StateNotifier<String> {
  DeviceNameNotifier(this._repo) : super('FlashDrop Android') {
    unawaited(_load());
  }

  final HistoryRepository _repo;

  Future<void> _load() async {
    final saved = await _repo.loadDeviceName();
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = trimmed;
    await _repo.saveDeviceName(trimmed);
  }
}
