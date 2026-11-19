# FlashDrop Android Architecture

## Layered Design
- **Presentation (`lib/screens/`, `lib/widgets/`, `lib/routing/`)**: Material 3 UI driven by Riverpod providers and GoRouter. Zero networking or platform-channel code.
- **Application (`lib/providers/`)**: `DiscoveryNotifier`, `ConnectionNotifier`, and `TransferNotifier` coordinate timeouts, duplicate filtering, mutual authentication, multi-file queuing, and live throughput calculation.
- **Domain (`lib/models/`, `lib/core/`)**: Immutable models (`PeerDevice`, `TransferFile`, `TransferMetadata`, `TransferProgress`, `TransferSession`), typed errors, and path-traversal sanitization.
- **Transport (`lib/transport/`)**: Abstract `PeerTransport` interface implemented by `NearbyTransport` over `MethodChannel("com.flashdrop.app/transport")` and `EventChannel("com.flashdrop.app/events")`.
- **Native Android (`android/app/src/main/kotlin/com/flashdrop/app/`)**:
  - `NearbyBridge.kt`: Channel router and main-thread event dispatcher.
  - `DiscoveryManager.kt`: Nearby Connections advertising & discovery + adapter checks.
  - `ConnectionManager.kt`: Mutual authentication (`authenticationDigits`) and explicit user accept/reject lifecycle.
  - `TransferManager.kt`: Metadata JSON exchange (`Payload.fromBytes`) + native `ParcelFileDescriptor` file streaming (`Payload.fromFile`) + single-pass 64 KB buffered SHA-256 verification and atomic commit.
  - `WifiDirectManager.kt`: Optional Android-to-Android `WifiP2pManager` + 64 KB bounded TCP socket fallback.
  - `TransferForegroundService.kt`: Android 14+ `connectedDevice` foreground service keeping active transfers alive while locked/backgrounded.

## Transfer Protocol v1
1. Sender computes SHA-256 of the file in a background Dart `Isolate` (streaming chunks).
2. Sender transmits a validated JSON metadata frame (`protocolVersion: 1`, `transferId`, `fileName`, `fileSize`, `mimeType`, `checksum`, `fileIndex`, `totalFiles`).
3. Receiver validates all fields, sanitizes `fileName`, and displays incoming transfer details.
4. Sender streams the file payload via native `ParcelFileDescriptor`.
5. Receiver streams payload bytes to `cache/FlashDropTmp/<transferId>.part` while computing SHA-256 in a single pass.
6. Upon completion, Receiver checks exact byte size and SHA-256 equality, moves the file atomically to `FlashDrop/` (with collision-safe naming), and sends a signed JSON `ack` payload back to Sender.
