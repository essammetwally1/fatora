import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> savePdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final directory = await _resolveDownloadDirectory();

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File('${directory.path}/$fileName');

  await file.writeAsBytes(bytes, flush: true);

  return file.path;
}

Future<Directory> _resolveDownloadDirectory() async {
  try {
    final downloadsDirectory = await getDownloadsDirectory();

    if (downloadsDirectory != null) {
      return downloadsDirectory;
    }
  } catch (_) {
    // Some mobile platforms do not expose a public downloads directory.
  }

  return getApplicationDocumentsDirectory();
}
