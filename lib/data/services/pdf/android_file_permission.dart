import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidFilePermission {
  const AndroidFilePermission._();

  static Future<bool> ensureCanSaveFile() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Android 10+ uses scoped storage / file picker behavior.
    // No storage permission is needed for this PDF save flow.
    if (sdkInt >= 29) {
      return true;
    }

    final currentStatus = await Permission.storage.status;

    if (currentStatus.isGranted) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    final requestedStatus = await Permission.storage.request();

    return requestedStatus.isGranted;
  }
}
