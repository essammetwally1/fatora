import 'dart:typed_data';

import 'package:flutter_file_saver/flutter_file_saver.dart';

/// The user dismissed the system "save file" dialog.
///
/// Not a failure: nothing went wrong and nothing needs retrying, so callers
/// must report it differently from a save that actually broke.
class FileSaveCancelledException implements Exception {
  const FileSaveCancelledException();

  @override
  String toString() => 'FileSaveCancelledException';
}

/// Writes exported bytes to a location the user picks.
///
/// On Android this opens the system document picker once per file, which is
/// why multi-file exports have to handle cancellation between files.
class AppFileSaver {
  const AppFileSaver._();

  static Future<String> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      return await FlutterFileSaver().writeFileAsBytes(
        fileName: fileName,
        bytes: bytes,
      );
    } on FileSaverCancelledException {
      // Re-thrown as our own type so the UI never has to import the plugin to
      // tell "cancelled" apart from "failed".
      throw const FileSaveCancelledException();
    }
  }
}
