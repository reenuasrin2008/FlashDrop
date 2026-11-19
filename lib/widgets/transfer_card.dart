import 'package:flutter/material.dart';
import 'package:flashdrop/core/utilities/file_sanitizer.dart';
import 'package:flashdrop/models/transfer_progress.dart';
import 'package:flashdrop/models/transfer_session.dart';

class TransferQueueCard extends StatelessWidget {
  const TransferQueueCard({
    super.key,
    required this.item,
    this.onRemove,
    this.onOpen,
  });

  final TransferQueueItem item;
  final VoidCallback? onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(_iconForMime(item.file.mimeType), color: scheme.primary),
        title: Text(
          item.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          item.errorMessage ??
              '${FileSanitizer.formatBytes(item.file.sizeBytes)} • ${_statusLabel(item.status)}',
          style: item.status == TransferItemStatus.failed
              ? TextStyle(color: scheme.error)
              : null,
        ),
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (onRemove != null && item.status == TransferItemStatus.waiting) {
      return IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: onRemove,
        tooltip: 'Remove file',
      );
    }
    switch (item.status) {
      case TransferItemStatus.completed:
        return onOpen != null
            ? TextButton(onPressed: onOpen, child: const Text('Open'))
            : Icon(Icons.check_circle_rounded, color: scheme.secondary);
      case TransferItemStatus.failed:
        return Icon(Icons.error_outline_rounded, color: scheme.error);
      case TransferItemStatus.inProgress:
      case TransferItemStatus.hashing:
      case TransferItemStatus.verifying:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      default:
        return Icon(Icons.schedule_rounded, color: scheme.outline);
    }
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.movie_rounded;
    if (mime.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (mime == 'application/zip') return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _statusLabel(TransferItemStatus status) {
    switch (status) {
      case TransferItemStatus.waiting:
        return 'Waiting';
      case TransferItemStatus.hashing:
        return 'Computing SHA-256';
      case TransferItemStatus.inProgress:
        return 'Transferring';
      case TransferItemStatus.verifying:
        return 'Verifying';
      case TransferItemStatus.completed:
        return 'Verified';
      case TransferItemStatus.failed:
        return 'Failed';
      case TransferItemStatus.cancelled:
        return 'Cancelled';
    }
  }
}
