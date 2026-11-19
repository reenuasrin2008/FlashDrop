# FlashDrop for Android

Ultra-fast offline peer-to-peer file sharing application built with **Flutter (Dart)** and **Native Android (Kotlin)** using the official [Google Play services Nearby Connections SDK](https://developers.google.com/nearby/connections/android/get-started) (`com.google.android.gms:play-services-nearby:19.5.1`) with an optional Android **Wi-Fi Direct (`WifiP2pManager`)** fallback.

## Key Capabilities
- **100% Offline**: No mobile data, internet access, cloud servers, or user accounts.
- **High-Speed Native Transport**: Uses BLE/Wi-Fi discovery via Nearby Connections `Strategy.P2P_POINT_TO_POINT`, automatically upgrading to high-bandwidth Wi-Fi Direct / Wi-Fi Aware for file transfer (never Bluetooth-only for large files).
- **Zero Full-File Memory Buffering**: Streams files natively via `ParcelFileDescriptor` (`Payload.fromFile`) and computes SHA-256 checksums in bounded 64 KB chunks off the UI thread.
- **Mutually Authenticated Connections**: Displays verification digits on both phones and requires explicit receiver approval before accepting connections or files.
- **SHA-256 Integrity Verification**: Every received file is written to temporary staging, verified for exact byte count and SHA-256 match, and moved atomically to the `FlashDrop/` folder with collision-safe naming.
- **Android 10–15+ Ready**: Declares scoped runtime permissions (`BLUETOOTH_SCAN` with `neverForLocation`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `NEARBY_WIFI_DEVICES`, and `FOREGROUND_SERVICE_CONNECTED_DEVICE` for Android 14+).

## Prerequisites
- Flutter SDK `>= 3.22.0` (Dart `>= 3.4.0`)
- Android Studio / Android SDK Platform 35 (`compileSdk = 35`, `minSdk = 24`)
- Java 17 (JDK 17)
- Two physical Android devices with Google Play services (emulators do not support real BLE/Wi-Fi Direct hardware discovery)

## Setup & Build Instructions
```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Run unit tests (metadata validation, filename sanitization, SHA-256 integrity, progress math)
flutter test

# 3. Run static analysis
flutter analyze

# 4. Build a debug APK for physical device testing
flutter build apk --debug

# 5. Build a release APK or App Bundle
flutter build apk --release
flutter build appbundle --release
```

## Android Permissions Matrix
| Android Version | Runtime Permissions Requested On-Demand | Reference |
|---|---|---|
| Android 10–11 (API 29–30) | `ACCESS_FINE_LOCATION` (required by OS for BLE/Wi-Fi scans) | [Android Permissions](https://developer.android.com/guide/topics/permissions/overview) |
| Android 12 (API 31–32) | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `ACCESS_FINE_LOCATION` | [Bluetooth Permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions) |
| Android 13+ (API 33+) | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `NEARBY_WIFI_DEVICES`, `POST_NOTIFICATIONS` | [Nearby Wi-Fi Permissions](https://developer.android.com/develop/connectivity/wifi/wifi-permissions) |
| Android 14+ (API 34+) | Manifest `FOREGROUND_SERVICE_CONNECTED_DEVICE` + `foregroundServiceType="connectedDevice"` | [Foreground Service Types](https://developer.android.com/about/versions/14/changes/fgs-types-required) |

## Physical Device Testing Checklist
1. Turn **off** Mobile Data and disconnect from internet Wi-Fi routers (leave Wi-Fi and Bluetooth radios enabled).
2. Open FlashDrop on Phone A (tap **Send**) and Phone B (tap **Receive**).
3. Confirm Phone B appears on Phone A, tap to connect, verify matching authentication digits on both screens, and tap **Accept**.
4. Test small documents, multi-photo batches, and >1 GB video files; verify SHA-256 checksum pass and inspect real throughput in **Settings → Benchmarks**.
5. Test connection drop (toggle Airplane Mode mid-transfer) and verify clean error reporting and temporary file cleanup.

## Platform Interoperability Note
This deliverable targets **Android** as requested. Android-to-Android transfers use Google Nearby Connections (`P2P_POINT_TO_POINT`) or the optional Wi-Fi Direct fallback. Cross-platform Android ↔ iOS transfers require adding the iOS `Runner` Swift bridge using the official Google Nearby Connections Swift SDK (Android Wi-Fi Direct does not interoperate directly with iOS).

## Google Play Protect & Release Signing Compliance
FlashDrop is configured to align with [Google Play Protect developer guidance](https://developers.google.com/android/play-protect/warning-dev-guidance) and [Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config):
- **Minimum Scoped Permissions**: Zero high-risk permissions (`READ_SMS`, `BIND_ACCESSIBILITY_SERVICE`, `REQUEST_INSTALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`, or `QUERY_ALL_PACKAGES`).
- **Hardened Manifest**: `android:allowBackup="false"`, `android:usesCleartextTraffic="false"`, `@xml/network_security_config`, `targetSdk = 35`, and `android:exported="false"` on all internal services/providers.
- **Release Signing on GitHub Actions**: Add repository secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` to sign `flashdrop-release.apk` with your own release certificate instead of the default debug key. Note: for any brand-new sideloaded APK not yet published on Google Play, Play Protect may show a one-time "Send app for security check" prompt until Google scans the binary or the app is registered via Play Console.
