enum FlashDropErrorCode {
  permissionDenied,
  adapterDisabled,
  discoveryFailed,
  connectionFailed,
  connectionRejected,
  transferFailed,
  integrityMismatch,
  insufficientStorage,
  invalidMetadata,
  cancelled,
  timeout,
}

class FlashDropException implements Exception {
  const FlashDropException(
    this.code,
    this.message, {
    this.cause,
  });

  final FlashDropErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'FlashDropException($code): $message';
}
