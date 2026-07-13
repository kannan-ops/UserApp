import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:enquiry_app/appcontroler/appcontroler/device_service.dart';
import 'package:enquiry_app/screens/please_update_screen.dart';
import 'package:enquiry_app/main.dart';
import 'package:enquiry_app/services/secure_storage_service.dart';

class CustomFlowService {
  static bool updateRequired = false;

  static void redirectToUpdateScreen() {
    updateRequired = true;
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PleaseUpdateScreen()),
        (route) => false,
      );
    }
  }

  static Future<void> cleanupOldCachedAppId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keys = prefs.getKeys();
      for (var key in keys) {
        try {
          final val = prefs.get(key);
          if (val is String) {
            if (val.contains('PAYMENT-APP-79703') ||
                val.contains('USER-APP-57591') ||
                val.contains('USER-APP-51056')) {
              await prefs.remove(key);
            }
          }
        } catch (_) {}
      }

      final secureStorage = await SecureStorageService.getInstance();
      final secKeys = ['app_id', 'appId', 'AppID', 'App ID'];
      for (var key in secKeys) {
        final val = secureStorage.readSecure(key);
        if (val == 'PAYMENT-APP-79703' ||
            val == 'USER-APP-57591' ||
            val == 'USER-APP-51056') {
          await secureStorage.deleteSecure(key);
        }
      }
    } catch (_) {}
  }

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasRunBefore = prefs.getBool('has_run_before') ?? false;
    return !hasRunBefore;
  }

  static Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_run_before', true);
  }

  static Future<Map<String, dynamic>> _getCommonParams(String userId) async {
    String deviceId = '';
    try {
      deviceId = await DeviceService.getDeviceId();
    } catch (_) {}

    String version = '1.0.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
    } catch (_) {}

    final String platformName = Platform.isAndroid ? 'Android' : 'iOS';

    String deviceName = 'Mobile Device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = "${androidInfo.brand} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }
    } catch (_) {}

    return {
      'userid': userId,
      'userId': userId,
      'device_id': deviceId,
      'deviceId': deviceId,
      'device': 'Mobile',
      'version': version,
      'software_version': '1.4.1',
      'softwareVersion': '1.4.1',
      'platform_name': platformName,
      'platformName': platformName,
      'platform': platformName,
      'device_name': deviceName,
      'deviceName': deviceName,
      'app_id': 'USERAPP-95386',
      'appId': 'USERAPP-95386',
      'status': 'Active',
    };
  }

  static bool _isValidResponse(dynamic response) {
    if (response == null ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      return false;
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('success')) {
        return data['success'] == true;
      }
    } catch (_) {}
    return true;
  }

  static Future<bool> checkFirstTimeUserAppData(String userId) async {
    try {
      final url = Uri.parse(
        "https://mobilevalidation.srivagroups.in/api/UserAppData",
      );
      final body = await _getCommonParams(userId);

      debugPrint("Sending app_id: ${body['app_id']}");
      final response = await ApiDebugLogger.httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (_isValidResponse(response)) {
        await markFirstLaunchCompleted();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkSplashFlow(String userId) async {
    try {
      final userAppUrl = Uri.parse(
        "https://mobilevalidation.srivagroups.in/api/UserAppData",
      );
      final body = await _getCommonParams(userId);

      debugPrint("Sending app_id: ${body['app_id']}");
      final userAppResponse = await ApiDebugLogger.httpClient
          .post(
            userAppUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (!_isValidResponse(userAppResponse)) {
        return false;
      }
    } catch (e) {
      return false;
    }

    try {
      final addVersionUrl = Uri.parse(
        "https://mobileadmin.srivagroups.in/api/add-version",
      );
      final body = await _getCommonParams(userId);

      debugPrint("Sending app_id: ${body['app_id']}");
      final addVersionResponse = await ApiDebugLogger.httpClient
          .post(
            addVersionUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (_isValidResponse(addVersionResponse)) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkLoginAppToken(String userId, String token) async {
    try {
      final url = Uri.parse(
        "https://mobileadmin.srivagroups.in/api/add-app-token",
      );
      final body = await _getCommonParams(userId);
      body['token'] = token;
      body['app_token'] = token;
      body['appToken'] = token;

      body['lifetime'] = 86400;
      body['lifetime_unit'] = 'seconds';
      body['App ID'] = 'USERAPP-95386';
      body['AppID'] = 'USERAPP-95386';
      body['App Id'] = 'USERAPP-95386';
      body['app_id'] = 'USERAPP-95386';
      body['appId'] = 'USERAPP-95386';
      body['API Endpoint'] = 'add-app-token';
      body['APIEndpoint'] = 'add-app-token';
      body['api_endpoint'] = 'add-app-token';
      body['apiEndpoint'] = 'add-app-token';
      body['endpoint'] = 'add-app-token';

      debugPrint("Sending app_id: ${body['app_id']}");
      final response = await ApiDebugLogger.httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        return true;
      }

      if (_isValidResponse(response)) {
        return true;
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  static Future<bool> checkAppToAppToken(String userId, String token) async {
    try {
      final url = Uri.parse("https://mobileadmin.srivagroups.in/api/add-token");
      final body = await _getCommonParams(userId);
      body['token'] = token;
      body['app_token'] = token;
      body['appToken'] = token;

      body['lifetime'] = 86400;
      body['lifetime_unit'] = 'seconds';

      debugPrint("Sending app_id: ${body['app_id']}");
      final response = await ApiDebugLogger.httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        return true;
      }

      if (_isValidResponse(response)) {
        return true;
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  static Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (updateRequired) {
        redirectToUpdateScreen();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final String userId = prefs.getString('user_id') ?? '';
      final String token = prefs.getString('auth_token') ?? '';

      if (userId.isNotEmpty && token.isNotEmpty) {
        final bool success = await checkAppToAppToken(userId, token);
        if (!success) {
          updateRequired = true;
          redirectToUpdateScreen();
        }
      }
    }
  }
}
