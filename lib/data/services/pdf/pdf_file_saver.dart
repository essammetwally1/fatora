import 'dart:typed_data';

import 'package:flutter_file_saver/flutter_file_saver.dart';

class PdfFileSaver {
  const PdfFileSaver._();

  static Future<String> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final savedPath = await FlutterFileSaver().writeFileAsBytes(
      fileName: fileName,
      bytes: bytes,
    );

    return savedPath;
  }
}
