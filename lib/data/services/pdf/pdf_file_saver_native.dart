import 'dart:typed_data';

import 'package:flutter_file_saver/flutter_file_saver.dart';

Future<String> savePdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final result = await FlutterFileSaver().writeFileAsBytes(
    fileName: fileName,
    bytes: bytes,
  );

  return result;
}
