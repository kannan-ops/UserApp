import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'device_service.dart';

class DeviceSecurityService {
  static Future<Map<String, dynamic>> getSecurityPayload({
    bool fetchLocation = true,
  }) async {
    final String deviceId = await DeviceService.getDeviceId();

    String deviceModel = 'unknown';
    try {
      if (Platform.isAndroid) {
        deviceModel = deviceId;
      } else if (Platform.isIOS) {
        deviceModel = deviceId;
      }
    } catch (_) {}

    String appVersion = 'unknown';
    try {
      final pkgInfo = await PackageInfo.fromPlatform();
      appVersion = pkgInfo.version;
    } catch (_) {}

    double? latitude;
    double? longitude;
    String? readableAddress;
    if (fetchLocation) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Permission.location.status;
          if (!permission.isGranted) {
            permission = await Permission.location.request();
          }
          if (permission.isGranted) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            latitude = position.latitude;
            longitude = position.longitude;

            readableAddress = 'Location captured';
          }
        }
      } catch (_) {}
    }

    return {
      'device_id': deviceId,
      'device_model': deviceModel,
      'platform': Platform.operatingSystem,
      'version': appVersion,
      'latitude': latitude,
      'longitude': longitude,
      'readable_address': readableAddress,
      'sim_info': [],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
