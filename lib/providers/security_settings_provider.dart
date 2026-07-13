import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/models/security_setting.dart';
import 'package:enquiry_app/services/security_settings_service.dart';
import 'package:enquiry_app/services/api_service.dart';

class SecuritySettingsProvider extends ChangeNotifier {
  final SecuritySettingsService _settingsService = SecuritySettingsService(
    ApiService(),
  );

  List<SecuritySetting> _settings = [];
  final bool _isLoading = false;
  String? _errorMessage;
  String? _pendingKey;
  bool _isFetching = false;
  bool _isUpdating = false;

  List<SecuritySetting> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get pendingKey => _pendingKey;

  bool _hasFetched = false;
  bool get hasFetched => _hasFetched;
  int? _fetchedUserId;

  final int userId = 12;

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

  Future<void>? _activeFetchFuture;
  Future<bool>? _activeUpdateFuture;

  SecuritySettingsProvider() {
    _initializeDefaultSettings();
  }

  void _initializeDefaultSettings() {
    _settings = [
      SecuritySetting(
        key: 'pincode',
        title: 'Pincode Protection',
        subtitle: 'Require custom 4-digit PIN code matching',
        icon: Icons.dialpad_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'fingerprint',
        title: 'Fingerprint Protection',
        subtitle: 'Validate active fingerprint hardware',
        icon: Icons.fingerprint_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'face_lock',
        title: 'Face Unlock',
        subtitle: 'Require face scanner matching',
        icon: Icons.face_retouching_natural_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'otp_verification',
        title: 'OTP Verification',
        subtitle: 'Request temporary one-time password code',
        icon: Icons.mark_as_unread_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'device_lock',
        title: 'Device Lock',
        subtitle: 'Secure clearance validation parameters',
        icon: Icons.lock_outline_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'location_access',
        title: 'Location Access',
        subtitle: 'Enforce geo-fencing location clearances',
        icon: Icons.location_on_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'login_alert',
        title: 'Login Alert',
        subtitle: 'Notify on new security clears',
        icon: Icons.notifications_active_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'screen_security',
        title: 'Screen Security',
        subtitle: 'Ensure maximum display protection',
        icon: Icons.screenshot_monitor_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'screenshot_block',
        title: 'Screenshot Block',
        subtitle: 'Prohibit screen captures and storage',
        icon: Icons.block_flipped,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'session_timeout',
        title: 'Session Timeout',
        subtitle: 'Terminate operational idle sessions',
        icon: Icons.timer_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'pattern_lock',
        title: 'Pattern Lock',
        subtitle: 'Require gesture pattern matching',
        icon: Icons.gesture_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'grid_card',
        title: 'Grid Card Lock',
        subtitle: 'Validate active grid matrix coordinate clears',
        icon: Icons.grid_view_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'security_tab',
        title: 'Security Tab Lock',
        subtitle: 'Protect active transactions and operations',
        icon: Icons.security_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'mail_otp',
        title: 'Mail OTP Lock',
        subtitle: 'Receive MFA one-time codes via email',
        icon: Icons.alternate_email_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'whatsapp_otp',
        title: 'WhatsApp OTP Lock',
        subtitle: 'Receive MFA one-time codes via WhatsApp',
        icon: Icons.chat_bubble_outline_rounded,
        isEnabled: false,
      ),
      SecuritySetting(
        key: 'sms_otp',
        title: 'SMS OTP Lock',
        subtitle: 'Receive MFA one-time codes via SMS text',
        icon: Icons.sms_outlined,
        isEnabled: false,
      ),
    ];
  }

  Future<void> fetchSettings({int? userId, bool force = false}) {
    final targetUserId = userId ?? this.userId;
    if (_isFetching && _activeFetchFuture != null) {
      debugPrint(
        "[PROVIDER MUTEX] settings fetch already in progress. Collapsing duplicate call.",
      );
      return _activeFetchFuture!;
    }
    if (_hasFetched && !force && _fetchedUserId == targetUserId) {
      return Future.value();
    }

    _activeFetchFuture = _executeFetchSettings(targetUserId, force)
        .whenComplete(() {
          _activeFetchFuture = null;
        });

    return _activeFetchFuture!;
  }

  Future<void> _executeFetchSettings(int targetUserId, bool force) async {
    _isFetching = true;
    _errorMessage = null;
    _fetchedUserId = targetUserId;

    try {
      final prefs = await SharedPreferences.getInstance();

      bool parseBool(dynamic val) {
        if (val == null) return false;
        if (val is bool) return val;
        final String str = val.toString().toLowerCase().trim();
        return str == 'enable' ||
            str == '1' ||
            str == 'true' ||
            str == 'active';
      }

      _settings = _settings.map((setting) {
        if (backendKeys.contains(setting.key)) {
          final cachedValue =
              prefs.getBool('sec_cache_${setting.key}') ?? false;
          return setting.copyWith(isEnabled: cachedValue);
        } else {
          final localValue = prefs.getBool('sec_local_${setting.key}') ?? false;
          return setting.copyWith(isEnabled: localValue);
        }
      }).toList();

      _hasFetched = true;

      notifyListeners();

      Map<String, dynamic> data = {};
      try {
        data = await _settingsService.getSecuritySettings(targetUserId);
      } catch (e) {
        debugPrint("SecuritySettingsProvider [Fetch background]: $e");
      }

      if (data.isNotEmpty) {
        final dataMap = data['data'] is Map ? data['data'] : data;
        bool hasChanges = false;
        _settings = _settings.map((setting) {
          if (backendKeys.contains(setting.key)) {
            final backendValue = dataMap[setting.key];
            if (backendValue != null) {
              final bool isBackendEnabled = parseBool(backendValue);

              final cachedValue =
                  prefs.getBool('sec_cache_${setting.key}') ?? false;
              if (cachedValue != isBackendEnabled) {
                hasChanges = true;
                prefs.setBool('sec_cache_${setting.key}', isBackendEnabled);
              }
              return setting.copyWith(isEnabled: isBackendEnabled);
            } else {
              final cachedValue =
                  prefs.getBool('sec_cache_${setting.key}') ?? false;
              return setting.copyWith(isEnabled: cachedValue);
            }
          }
          return setting;
        }).toList();

        if (hasChanges) {
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  Future<bool> updateSetting(String key, bool value, {int? userId}) {
    if (_isUpdating && _activeUpdateFuture != null) {
      debugPrint(
        "[PROVIDER MUTEX] settings update already in progress. Collapsing duplicate call.",
      );
      return _activeUpdateFuture!;
    }

    _activeUpdateFuture = _executeUpdateSetting(key, value, userId)
        .whenComplete(() {
          _activeUpdateFuture = null;
        });

    return _activeUpdateFuture!;
  }

  Future<bool> _executeUpdateSetting(
    String key,
    bool value,
    int? passedUserId,
  ) async {
    _isUpdating = true;
    _pendingKey = key;

    final targetUserId = passedUserId ?? userId;
    notifyListeners();

    debugPrint(
      "Setting Changed -> User ID: $targetUserId, Key: $key, Enabled: $value",
    );

    try {
      final prefs = await SharedPreferences.getInstance();

      if (backendKeys.contains(key)) {
        final Map<String, String> backendPayload = {};
        for (var k in backendKeys) {
          final settingItem = _settings.firstWhere(
            (s) => s.key == k,
            orElse: () => SecuritySetting(
              key: k,
              title: '',
              subtitle: '',
              icon: Icons.shield,
              isEnabled: false,
            ),
          );
          final bool activeVal = (k == key) ? value : settingItem.isEnabled;
          backendPayload[k] = activeVal ? 'enable' : 'disable';
        }

        await _settingsService.updateSecuritySetting(
          userId: targetUserId,
          backendPayload: backendPayload,
        );

        await prefs.setBool('sec_cache_$key', value);
      } else {
        await prefs.setBool('sec_local_$key', value);
      }

      _settings = _settings.map((setting) {
        if (setting.key == key) {
          return setting.copyWith(isEnabled: value);
        }
        return setting;
      }).toList();

      _pendingKey = null;
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Security Setting Sync Failed: $e");
      _errorMessage = e.toString().replaceAll('Exception: ', '');

      _pendingKey = null;
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }
}
