import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flashdrop/models/transfer_file.dart';

class FileService {
  static const _uuid = Uuid();

  Future<List<TransferFile>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      withReadStream: false,
    );
    if (result == null) return const [];

    final selected = <TransferFile>[];
    for (final pf in result.files) {
      final path = pf.path;
      if (path == null) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      selected.add(
        TransferFile(
          id: _uuid.v4(),
          name: pf.name,
          path: path,
          sizeBytes: pf.size,
          mimeType: _inferMimeType(pf.name),
        ),
      );
    }
    return selected;
  }

  Future<Directory> getReceivedDirectory() async {
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'FlashDrop'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }

  String _inferMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      case '.zip':
        return 'application/zip';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
