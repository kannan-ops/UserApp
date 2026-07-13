import 'package:enquiry_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TwoStepAuthService {
  final ApiService _apiService;

  TwoStepAuthService(this._apiService);

  Future<Map<String, dynamic>> updateTwoStepAuth({
    required int userId,
    required bool gridCard,
    required bool securityTab,
    required bool mailOtp,
    required bool whatsappOtp,
    required bool smsOtp,
    required bool fingerprint,
    required bool faceLock,
    required bool patternLock,
    required String pincode,
  }) async {
    print("========== UPDATE TWO STEP AUTH ==========");
    print("User ID: $userId");
    print("MFA Grid Card lock active: $gridCard");
    print("MFA Security Tab lock active: $securityTab");
    print("MFA Mail OTP lock active: $mailOtp");
    print("MFA WhatsApp OTP lock active: $whatsappOtp");
    print("MFA SMS OTP lock active: $smsOtp");
    print("MFA Fingerprint lock active: $fingerprint");
    print("MFA Face Lock lock active: $faceLock");
    print("MFA Pattern Lock lock active: $patternLock");
    print("MFA Pincode configured: $pincode");

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'grid_card': gridCard ? 1 : 0,
      'security_tab': securityTab ? 1 : 0,
      'mail_otp': mailOtp ? 1 : 0,
      'whatsapp_otp': whatsappOtp ? 1 : 0,
      'sms_otp': smsOtp ? 1 : 0,
      'fingerprint': fingerprint ? 1 : 0,
      'face_lock': faceLock ? 1 : 0,
      'pattern_lock': patternLock ? 1 : 0,
      'pincode': pincode,
    };

    try {
      final result = await _apiService.request(
        path: '/two-step-authentication/update',
        method: 'PUT',
        body: requestBody,
      );

      print("Update Two-Step Authentication API success");
      return result is Map<String, dynamic> ? result : {'success': true};
    } catch (e, stackTrace) {
      print("========== EXCEPTION (Update Two-Step Auth) ==========");
      print("ERROR: $e");
      print("STACKTRACE:");
      print(stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSecuritySettings(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String phone = prefs.getString('user_phone') ?? '';
      final String identifier = phone.isNotEmpty ? phone : userId.toString();

      final result = await _apiService.request(
        customBaseUrl: 'https://lockscreen.srivagroups.in/api',
        path: '/security/update-settings/$identifier',
        method: 'GET',
      );
      print("Get Security Settings API success: $result");
      return result is Map<String, dynamic> ? result : {};
    } catch (e, stackTrace) {
      print("========== EXCEPTION (Get Security Settings) ==========");
      print("ERROR: $e");
      print("STACKTRACE:");
      print(stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSecuritySettings({
    required int userId,
    required bool fingerprint,
    required bool faceLock,
    required bool patternLock,
    required bool pincode,
    required bool gridCard,
    required bool securityTab,
    required bool mailOtp,
    required bool whatsappOtp,
    required bool smsOtp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String phone = prefs.getString('user_phone') ?? '';
    final String identifier = phone.isNotEmpty ? phone : userId.toString();

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'fingerprint': fingerprint ? 'enable' : 'disable',
      'face_lock': faceLock ? 'enable' : 'disable',
      'pattern_lock': patternLock ? 'enable' : 'disable',
      'pincode': pincode ? 'enable' : 'disable',
      'grid_card': gridCard ? 'enable' : 'disable',
      'security_tab': securityTab ? 'enable' : 'disable',
      'mail_otp': mailOtp ? 'enable' : 'disable',
      'whatsapp_otp': whatsappOtp ? 'enable' : 'disable',
      'sms_otp': smsOtp ? 'enable' : 'disable',
    };

    print(
      "========== UPDATE SECURITY SETTINGS (enable/disable format) ==========",
    );
    print("Request Body: $requestBody");

    try {
      final result = await _apiService.request(
        customBaseUrl: 'https://lockscreen.srivagroups.in/api',
        path: '/security/update-settings/$identifier',
        method: 'POST',
        body: requestBody,
      );
      print("Update Security Settings API success");
      return result is Map<String, dynamic> ? result : {'success': true};
    } catch (e, stackTrace) {
      print("========== EXCEPTION (Update Security Settings) ==========");
      print("ERROR: $e");
      print("STACKTRACE:");
      print(stackTrace);
      rethrow;
    }
  }
}
