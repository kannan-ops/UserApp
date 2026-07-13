import 'package:enquiry_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecuritySettingsService {
  final ApiService _apiService;

  SecuritySettingsService(this._apiService);

  Future<Map<String, dynamic>> getSecuritySettings(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final String phone = prefs.getString('user_phone') ?? '';
    final String identifier = phone.isNotEmpty ? phone : userId.toString();

    final result = await _apiService.request(
      customBaseUrl: 'https://lockscreen.srivagroups.in/api',
      path: '/security/update-settings/$identifier',
      method: 'GET',
    );
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> updateSecuritySetting({
    required int userId,
    required Map<String, String> backendPayload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String phone = prefs.getString('user_phone') ?? '';
    final String identifier = phone.isNotEmpty ? phone : userId.toString();

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      ...backendPayload,
    };
    final result = await _apiService.request(
      customBaseUrl: 'https://lockscreen.srivagroups.in/api',
      path: '/security/update-settings/$identifier',
      method: 'POST',
      body: requestBody,
    );
    return result is Map<String, dynamic> ? result : {};
  }
}
