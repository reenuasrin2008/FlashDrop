class AppConstants {
  AppConstants._();

  static const String appName = 'FlashDrop';
  static const String tagline = 'Share files. No internet required.';
  static const String methodChannelName = 'com.flashdrop.app/transport';
  static const String eventChannelName = 'com.flashdrop.app/events';
  static const int protocolVersion = 1;
  static const Duration discoveryTimeout = Duration(seconds: 60);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const int hashChunkSizeBytes = 64 * 1024;
}
