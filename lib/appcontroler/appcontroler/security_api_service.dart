import 'dart:async';
import 'dart:convert';
import 'package:enquiry_app/utils/api_debug_logger.dart';

import 'api_config.dart';

class SecurityApiService {
  static Future<Map<String, dynamic>> sendUserAppData({
    required String userid,
    required String usernameOrEmail,
    required String password,
    required String phoneNumber,
    required String version,
    required String softwareVersion,
    required String imeNumber,
    required String deviceId,
    required String latitude,
    required String longitude,
    required String appName,
  }) async {
    final url = Uri.parse(ApiConfig.userAppData);
    final Map<String, dynamic> body = {
      "userid": userid,
      "username_or_email": usernameOrEmail,
      "password": password,
      "phone_number": phoneNumber,
      "version": version,
      "software_version": softwareVersion,
      "ime_number": imeNumber,
      "device_id": deviceId,
      "latitude": latitude.isEmpty ? "" : latitude,
      "longitude": longitude.isEmpty ? "" : longitude,
      "app_name": appName,
    };

    try {
      final response = await ApiDebugLogger.httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Security Verification Saved Successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        dynamic decodedBody;
        try {
          decodedBody = jsonDecode(response.body);
        } catch (_) {}
        final errorMsg =
            (decodedBody != null &&
                decodedBody is Map &&
                decodedBody.containsKey('message'))
            ? decodedBody['message']
            : 'Server error: ${response.statusCode}';
        return {'success': false, 'message': errorMsg};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timed out. Please check your internet.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection failed. Please check your internet connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> performAutoSecurityVerification({
    required String userid,
    required String version,
    required String softwareVersion,
    required String deviceId,
  }) async {
    const String dummyEmail = '';
    const String dummyPassword = '';
    const String dummyPhone = '';
    const String dummyIme = '';
    const String dummyAppName = 'Payment App';
    return await sendUserAppData(
      userid: userid,
      usernameOrEmail: dummyEmail,
      password: dummyPassword,
      phoneNumber: dummyPhone,
      version: version,
      softwareVersion: softwareVersion,
      imeNumber: dummyIme,
      deviceId: deviceId,
      latitude: '',
      longitude: '',
      appName: dummyAppName,
    );
  }
}
