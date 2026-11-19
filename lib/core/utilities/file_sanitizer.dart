import 'dart:math' as math;

class FileSanitizer {
  FileSanitizer._();

  static final RegExp _invalidChars = RegExp(r'[\x00-\x1F\x7F:*?"<>|]');

  /// Strips directory components, path-traversal tokens, and invalid filename characters.
  static String sanitizeFileName(String rawName) {
    final normalized = rawName.replaceAll('\\', '/');
    final baseName = normalized.split('/').last;
    var cleaned = baseName.replaceAll(_invalidChars, '_').trim();
    while (cleaned.startsWith('.')) {
      cleaned = cleaned.substring(1);
    }
    while (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'received_file';
    }
    if (cleaned.length > 200) {
      final dot = cleaned.lastIndexOf('.');
      if (dot > 0 && cleaned.length - dot <= 16) {
        final ext = cleaned.substring(dot);
        cleaned = '${cleaned.substring(0, 200 - ext.length)}$ext';
      } else {
        cleaned = cleaned.substring(0, 200);
      }
    }
    return cleaned;
  }

  /// Generates a collision-safe filename given a set of existing filenames in the target directory.
  static String resolveCollision(String fileName, Set<String> existingNames) {
    final safe = sanitizeFileName(fileName);
    if (!existingNames.contains(safe)) return safe;
    final dot = safe.lastIndexOf('.');
    final stem = dot > 0 ? safe.substring(0, dot) : safe;
    final ext = dot > 0 ? safe.substring(dot) : '';
    var counter = 1;
    while (true) {
      final candidate = '${stem}_($counter)$ext';
      if (!existingNames.contains(candidate)) return candidate;
      counter++;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final digitGroups = (math.log(bytes) / math.log(1024)).floor().clamp(0, units.length - 1);
    final value = bytes / math.pow(1024, digitGroups);
    return '${value.toStringAsFixed(digitGroups == 0 ? 0 : 1)} ${units[digitGroups]}';
  }

  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0 || bytesPerSecond.isNaN || bytesPerSecond.isInfinite) {
      return '0 B/s';
    }
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 1) return '< 1s';
    if (duration.inMinutes < 1) return '${duration.inSeconds}s';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (duration.inHours < 1) return '${minutes}m ${seconds}s';
    final hours = duration.inHours;
    return '${hours}h ${minutes % 60}m';
  }
}
