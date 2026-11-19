import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionCheckResult {
  const PermissionCheckResult({
    required this.granted,
    required this.permanentlyDenied,
    this.missingDescriptions = const [],
  });

  final bool granted;
  final bool permanentlyDenied;
  final List<String> missingDescriptions;
}

class PermissionManager {
  /// Requests only the permissions needed for offline nearby discovery & transfer on Android.
  Future<PermissionCheckResult> requestTransferPermissions({int androidSdkInt = 34}) async {
    if (!Platform.isAndroid) {
      return const PermissionCheckResult(granted: true, permanentlyDenied: false);
    }

    final required = <Permission, String>{};
    if (androidSdkInt >= 31) {
      required[Permission.bluetoothScan] = 'Bluetooth Scan (find nearby phones)';
      required[Permission.bluetoothConnect] = 'Bluetooth Connect (pair transfer session)';
      required[Permission.bluetoothAdvertise] = 'Bluetooth Advertise (make phone visible to receive)';
    }
    if (androidSdkInt >= 33) {
      required[Permission.nearbyWifiDevices] = 'Nearby Wi-Fi Devices (high-speed direct Wi-Fi transfer)';
      required[Permission.notification] = 'Notifications (keep active transfer visible in background)';
    }
    if (androidSdkInt <= 32) {
      required[Permission.locationWhenInUse] = 'Location (required by Android 12 and older for BLE/Wi-Fi scans)';
    }

    final statuses = await required.keys.toList().request();
    final missing = <String>[];
    var permanentlyDenied = false;

    for (final entry in required.entries) {
      final status = statuses[entry.key];
      // Notification denial does not block foreground transfers
      if (entry.key == Permission.notification) continue;
      if (status == null || !status.isGranted) {
        missing.add(entry.value);
        if (status?.isPermanentlyDenied == true) {
          permanentlyDenied = true;
        }
      }
    }

    return PermissionCheckResult(
      granted: missing.isEmpty,
      permanentlyDenied: permanentlyDenied,
      missingDescriptions: missing,
    );
  }

  Future<bool> openSettings() => openAppSettings();
}
