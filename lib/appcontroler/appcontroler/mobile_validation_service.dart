import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'device_service.dart';
import 'validation_model.dart';

class MobileValidationService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, String>> fetchLocalDetails() async {
    final prefs = await SharedPreferences.getInstance();

    final String userId = prefs.getString('user_id') ?? '';

    final String deviceId = await DeviceService.getDeviceId();

    String version = '1.0.0';
    String appName = 'Payment App';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      appName = packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : 'Payment App';
    } catch (e) {
      print("[MobileValidationService] PackageInfo error: $e");
    }

    const String softwareVersion = '1.4.1';

    const String appId = 'USERAPP-95386';

    final String platformName = Platform.isAndroid ? 'Android' : 'iOS';

    String deviceName = 'Mobile Device';
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceName = "${androidInfo.brand} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }
    } catch (e) {
      print("[MobileValidationService] DeviceInfo error: $e");
    }

    return {
      'userId': userId,
      'version': version,
      'software_version': softwareVersion,
      'device_id': deviceId,
      'app_name': appName,
      'app_id': appId,
      'platform_name': platformName,
      'device_name': deviceName,
    };
  }

  static Future<bool> runAutomaticMobileValidation() async {
    try {
      final String urlStr = ApiConfig.variants;
      final Uri url = Uri.parse(urlStr);

      final response = await ApiDebugLogger.httpClient
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return false;
      }

      final dynamic decoded = jsonDecode(response.body);
      ValidationModel? matchedModel;

      if (decoded is List) {
        for (var item in decoded) {
          final model = ValidationModel.fromJson(item);
          if (model.appId == 'USERAPP-95386' &&
              model.status.toLowerCase() == 'active') {
            matchedModel = model;
            break;
          }
        }
        if (matchedModel == null && decoded.isNotEmpty) {
          matchedModel = ValidationModel.fromJson(decoded.first);
        }
      } else if (decoded is Map<String, dynamic>) {
        matchedModel = ValidationModel.fromJson(decoded);
      }

      if (matchedModel == null) {
        print("Validation Failed: Could not decode active validation model.");
        return false;
      }

      print("Validation Success: Fetched app variants configuration.");
      print("Matched Config: ${jsonEncode(matchedModel.toJson())}");

      final syncSuccess = await syncUserAppData();
      if (syncSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('verification_completed', true);
        return true;
      } else {
        print("Validation Failed: User App Data sync failed.");
        return false;
      }
    } on TimeoutException catch (e) {
      print("Validation Failed: Timeout exception - $e");
      return false;
    } on SocketException catch (e) {
      print("Validation Failed: Network connection exception - $e");
      return false;
    } catch (e) {
      print("Validation Failed: Unexpected exception - $e");
      return false;
    } finally {
      print("=========================================");
      print("--- MOBILE VALIDATION SYSTEM END ---");
      print("=========================================");
    }
  }

  static Future<bool> syncUserAppData() async {
    final prefs = await SharedPreferences.getInstance();
    final localDetails = await fetchLocalDetails();

    final String version = localDetails['version'] ?? '1.0.0';
    final String userId = localDetails['userId'] ?? '';
    final String deviceId = localDetails['device_id'] ?? '';
    const String softwareVersion = '1.4.1';

    if (userId.isEmpty || deviceId.isEmpty) {
      print(
        "[MobileValidationService] Skip sync: userId or deviceId is empty.",
      );
      return false;
    }

    final String sessionKey = 'synced_session_$userId';
    final bool alreadySyncedSession = prefs.getBool(sessionKey) ?? false;

    if (alreadySyncedSession) {
      print(
        "[MobileValidationService] Skip sync: already synced for this login session.",
      );
      return true;
    }

    final String urlStr =
        "https://mobilevalidation.srivagroups.in/api/userAppData";
    final Uri url = Uri.parse(urlStr);
    final Map<String, String> body = {
      "userid": userId,
      "device_id": deviceId,
      "version": version,
      "software_version": softwareVersion,
      "app_id": "USERAPP-95386",
    };

    final Map<String, String> headers = {"Content-Type": "application/json"};

    final String timestamp = DateTime.now().toString();
    print("=============== API REQUEST ================");
    print("URL      : $urlStr");
    print("METHOD   : POST");
    print("HEADERS  : $headers");
    print("BODY     : ${jsonEncode(body)}");
    print("TIME     : $timestamp");
    print("======================");

    final startTime = DateTime.now();
    final client = ApiDebugLogger.wrapClient(http.Client());
    try {
      print("Sending app_id: USERAPP-95386");
      final response = await client
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      final duration = DateTime.now().difference(startTime);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("=============== API RESPONSE ===============");
        print("URL      : $urlStr");
        print("STATUS   : ${response.statusCode}");
        print("DURATION : ${duration.inMilliseconds} ms");
        print("BODY     : ${response.body}");
        print("=====================");

        await prefs.setBool(sessionKey, true);
        await prefs.setString('last_mobile_validation_response', response.body);

        await prefs.setBool('user_app_data_synced', true);
        await prefs.setBool('last_sync_network_error', false);
        return true;
      } else {
        print("=============== API ERROR =================");
        print("URL      : $urlStr");
        print("STATUS   : ${response.statusCode}");
        print("MESSAGE  : HTTP Error ${response.statusCode}");
        print("RESPONSE : ${response.body}");
        print("==========================");

        await prefs.setBool('user_app_data_synced', false);
        await prefs.setBool('last_sync_network_error', false);
        return false;
      }
    } catch (e) {
      print("=============== API ERROR =================");
      print("URL      : $urlStr");
      print("STATUS   : 500");
      print("MESSAGE  : $e");
      print("RESPONSE : null");
      print("==========================");

      await prefs.setBool('user_app_data_synced', false);
      final bool isNetworkError = e is SocketException || e is TimeoutException;
      await prefs.setBool('last_sync_network_error', isNetworkError);
      return false;
    } finally {
      client.close();
    }
  }
}
