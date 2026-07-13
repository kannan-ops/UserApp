import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/services/secure_storage_service.dart';

class LockRepository {
  final ApiService _apiService;
  final SecureStorageService _secureStorage;

  static const Set<String> backendKeys = {
    'pincode',
    'fingerprint',
    'face_lock',
    'pattern_lock',
    'grid_card',
    'security_tab',
    'mail_otp',
    'whatsapp_otp',
    'sms_otp',
  };

  LockRepository({
    required ApiService apiService,
    required SecureStorageService secureStorage,
  }) : _apiService = apiService,
       _secureStorage = secureStorage;

  Future<Map<String, bool>> fetchLockSettings(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String phone = prefs.getString('user_phone') ?? '';
      final String identifier = phone.isNotEmpty ? phone : userId.toString();

      debugPrint("========== SECURITY CONSOLE ==========");
      debugPrint("Fetching security settings...");
      debugPrint(
        "API URL: https://lockscreen.srivagroups.in/api/security/update-settings/$identifier",
      );
      final result = await _apiService.request(
        customBaseUrl: 'https://lockscreen.srivagroups.in/api',
        path: '/security/update-settings/$identifier',
        method: 'GET',
      );
      debugPrint("API Response: $result");

      final Map<String, bool> settingsMap = {};
      if (result is Map<String, dynamic> && result.isNotEmpty) {
        bool parseBool(dynamic val) {
          if (val == null) return false;
          if (val is bool) return val;
          final String str = val.toString().toLowerCase().trim();
          return str == 'enable' ||
              str == '1' ||
              str == 'true' ||
              str == 'active';
        }

        final dataMap = result['data'] is Map ? result['data'] : result;
        for (final key in backendKeys) {
          final dynamic val = dataMap[key];
          if (val != null) {
            final bool enabled = parseBool(val);
            settingsMap[key] = enabled;
            await _secureStorage.writeBoolSecure('enabled_$key', enabled);
          } else {
            settingsMap[key] = _secureStorage.readBoolSecure('enabled_$key');
          }
        }
        return settingsMap;
      } else {
        debugPrint("========== SECURITY CONSOLE ==========");
        debugPrint(
          "No security settings found. Creating default security settings row...",
        );
        final Map<String, bool> defaultSettings = {};
        for (final key in backendKeys) {
          defaultSettings[key] = false;
        }
        await syncLockSettings(userId, defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      debugPrint(
        "LockRepository: Failed to fetch from backend, relying on local secure cache: $e",
      );

      final Map<String, bool> cachedSettings = {};
      for (final key in backendKeys) {
        cachedSettings[key] = _secureStorage.readBoolSecure('enabled_$key');
      }
      return cachedSettings;
    }
  }

  Future<bool> syncLockSettings(int userId, Map<String, bool> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final String phone = prefs.getString('user_phone') ?? '';
    final String identifier = phone.isNotEmpty ? phone : userId.toString();

    final Map<String, String> backendPayload = {};
    for (final key in backendKeys) {
      final bool value = settings.containsKey(key)
          ? settings[key]!
          : _secureStorage.readBoolSecure('enabled_$key');
      backendPayload[key] = value ? 'enable' : 'disable';
    }

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      ...backendPayload,
    };

    try {
      debugPrint("Updating security setting...");
      debugPrint(
        "API URL: https://lockscreen.srivagroups.in/api/security/update-settings/$identifier",
      );
      debugPrint("Request Body: ${jsonEncode(requestBody)}");
      final result = await _apiService.request(
        customBaseUrl: 'https://lockscreen.srivagroups.in/api',
        path: '/security/update-settings/$identifier',
        method: 'POST',
        body: requestBody,
      );
      debugPrint("API Response: $result");

      final bool success = result != null;
      if (success) {
        for (final key in backendKeys) {
          final bool isEnabled = backendPayload[key] == 'enable';
          await _secureStorage.writeBoolSecure('enabled_$key', isEnabled);
        }
      }
      return success;
    } catch (e) {
      debugPrint(
        "LockRepository: Failed to update lock settings in backend: $e. Writing locally to cache to prevent user blocking.",
      );
      for (final key in backendKeys) {
        final bool isEnabled = backendPayload[key] == 'enable';
        await _secureStorage.writeBoolSecure('enabled_$key', isEnabled);
      }
      return true;
    }
  }

  Future<void> saveLocalConfig(
    String key,
    bool enabled, {
    String? value,
  }) async {
    await _secureStorage.writeBoolSecure('enabled_$key', enabled);
    if (value != null) {
      await _secureStorage.writeSecure('value_$key', value);
    }
  }

  bool getLocalEnabled(String key) {
    return _secureStorage.readBoolSecure('enabled_$key');
  }

  String getLocalValue(String key) {
    return _secureStorage.readSecure('value_$key');
  }

  Future<void> deleteLocalConfig(String key) async {
    await _secureStorage.deleteSecure('enabled_$key');
    await _secureStorage.deleteSecure('value_$key');
    await _secureStorage.deleteSecure('configured_$key');
  }

  Future<void> saveConfiguredState(String key, bool configured) async {
    await _secureStorage.writeBoolSecure('configured_$key', configured);
  }

  bool isLockConfigured(String key) {
    if (key == 'pincode' || key == 'pattern_lock') {
      final String val = getLocalValue(key);
      if (val.isEmpty) return false;
    }
    if (getLocalEnabled(key)) return true;
    return _secureStorage.readBoolSecure('configured_$key');
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final result = await _apiService.request(
        customBaseUrl: 'https://billing.srivagroups.in/api',
        path: '/pin-auth',
        method: 'POST',
        body: {'pin': pin},
      );
      if (result != null && result['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("LockRepository verifyPin exception: $e");
      return false;
    }
  }
}
