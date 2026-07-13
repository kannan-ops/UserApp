import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserRole = 'user_role';
  static const String keyUserLocation = 'user_location';
  static const String keyUserDeviceId = 'user_device_id';
  static const String keyUserLastLogin = 'user_last_login';
  static const String keyUserPhoto = 'user_photo';
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';

  static const String keyIsDarkMode = 'is_dark_mode';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyLanguage = 'language';
  static const String keyAutoSync = 'auto_sync';

  static const String keyIsPinEnabled = 'is_pin_enabled';
  static const String keyPinCode = 'pin_code';
  static const String keyIsPatternEnabled = 'is_pattern_enabled';
  static const String keyPatternCode = 'pattern_code';
  static const String keyIsBiometricEnabled = 'is_biometric_enabled';
  static const String keyIsAppLockEnabled = 'is_app_lock_enabled';
  static const String keyGridLockEnabled = 'grid_lock_enabled';

  static const String keyIsFingerprintEnabled = 'is_fingerprint_enabled';
  static const String keyIsFaceLockEnabled = 'is_face_lock_enabled';
  static const String keyAskBiometricsOnOpen = 'ask_biometrics_on_open';
  static const String keyAskBiometricsBeforeSecurity =
      'ask_biometrics_before_security';
  static const String keyAskBiometricsBeforeLogout =
      'ask_biometrics_before_logout';

  bool get isLoggedIn => _prefs?.getBool(keyIsLoggedIn) ?? false;
  Future<bool> setLoggedIn(bool value) async =>
      await _prefs?.setBool(keyIsLoggedIn, value) ?? false;

  String get userName => _prefs?.getString(keyUserName) ?? '';
  Future<bool> setUserName(String value) async =>
      await _prefs?.setString(keyUserName, value) ?? false;

  String get userEmail => _prefs?.getString(keyUserEmail) ?? '';
  Future<bool> setUserEmail(String value) async =>
      await _prefs?.setString(keyUserEmail, value) ?? false;

  String get userPhone =>
      _prefs?.getString(keyUserPhone) ?? '';
  Future<bool> setUserPhone(String value) async =>
      await _prefs?.setString(keyUserPhone, value) ?? false;

  String get userRole =>
      _prefs?.getString(keyUserRole) ?? '';
  Future<bool> setUserRole(String value) async =>
      await _prefs?.setString(keyUserRole, value) ?? false;

  String get userLocation =>
      _prefs?.getString(keyUserLocation) ?? 'San Francisco, CA';
  Future<bool> setUserLocation(String value) async =>
      await _prefs?.setString(keyUserLocation, value) ?? false;

  String get userDeviceId =>
      _prefs?.getString(keyUserDeviceId) ?? 'DEV-99A8-XF82-L093';
  Future<bool> setUserDeviceId(String value) async =>
      await _prefs?.setString(keyUserDeviceId, value) ?? false;

  String get userLastLogin =>
      _prefs?.getString(keyUserLastLogin) ?? '2026-05-26 09:15 AM';
  Future<bool> setUserLastLogin(String value) async =>
      await _prefs?.setString(keyUserLastLogin, value) ?? false;

  String get userPhoto => _prefs?.getString(keyUserPhoto) ?? '';
  Future<bool> setUserPhoto(String value) async =>
      await _prefs?.setString(keyUserPhoto, value) ?? false;

  String get authToken => _prefs?.getString(keyAuthToken) ?? '';
  Future<bool> setAuthToken(String value) async =>
      await _prefs?.setString(keyAuthToken, value) ?? false;

  String get userId => _prefs?.getString(keyUserId) ?? '';
  Future<bool> setUserId(String value) async =>
      await _prefs?.setString(keyUserId, value) ?? false;

  bool get isDarkMode => _prefs?.getBool(keyIsDarkMode) ?? true;
  Future<bool> setDarkMode(bool value) async =>
      await _prefs?.setBool(keyIsDarkMode, value) ?? false;

  bool get notificationsEnabled =>
      _prefs?.getBool(keyNotificationsEnabled) ?? true;
  Future<bool> setNotificationsEnabled(bool value) async =>
      await _prefs?.setBool(keyNotificationsEnabled, value) ?? false;

  String get language => _prefs?.getString(keyLanguage) ?? 'English';
  Future<bool> setLanguage(String value) async =>
      await _prefs?.setString(keyLanguage, value) ?? false;

  bool get autoSync => _prefs?.getBool(keyAutoSync) ?? true;
  Future<bool> setAutoSync(bool value) async =>
      await _prefs?.setBool(keyAutoSync, value) ?? false;

  bool get isPinEnabled => _prefs?.getBool(keyIsPinEnabled) ?? false;
  Future<bool> setPinEnabled(bool value) async =>
      await _prefs?.setBool(keyIsPinEnabled, value) ?? false;

  String get pinCode => _prefs?.getString(keyPinCode) ?? '';
  Future<bool> setPinCode(String value) async =>
      await _prefs?.setString(keyPinCode, value) ?? false;

  bool get isPatternEnabled => _prefs?.getBool(keyIsPatternEnabled) ?? false;
  Future<bool> setPatternEnabled(bool value) async =>
      await _prefs?.setBool(keyIsPatternEnabled, value) ?? false;

  String get patternCode => _prefs?.getString(keyPatternCode) ?? '';
  Future<bool> setPatternCode(String value) async =>
      await _prefs?.setString(keyPatternCode, value) ?? false;

  bool get isBiometricEnabled =>
      _prefs?.getBool(keyIsBiometricEnabled) ?? false;
  Future<bool> setBiometricEnabled(bool value) async =>
      await _prefs?.setBool(keyIsBiometricEnabled, value) ?? false;

  bool get isAppLockEnabled => _prefs?.getBool(keyIsAppLockEnabled) ?? false;
  Future<bool> setAppLockEnabled(bool value) async =>
      await _prefs?.setBool(keyIsAppLockEnabled, value) ?? false;

  bool get gridLockEnabled => _prefs?.getBool(keyGridLockEnabled) ?? false;
  Future<bool> setGridLockEnabled(bool value) async =>
      await _prefs?.setBool(keyGridLockEnabled, value) ?? false;

  bool get isFingerprintEnabled =>
      _prefs?.getBool(keyIsFingerprintEnabled) ?? false;
  Future<bool> setFingerprintEnabled(bool value) async =>
      await _prefs?.setBool(keyIsFingerprintEnabled, value) ?? false;

  bool get isFaceLockEnabled => _prefs?.getBool(keyIsFaceLockEnabled) ?? false;
  Future<bool> setFaceLockEnabled(bool value) async =>
      await _prefs?.setBool(keyIsFaceLockEnabled, value) ?? false;

  bool get askBiometricsOnOpen =>
      _prefs?.getBool(keyAskBiometricsOnOpen) ?? false;
  Future<bool> setAskBiometricsOnOpen(bool value) async =>
      await _prefs?.setBool(keyAskBiometricsOnOpen, value) ?? false;

  bool get askBiometricsBeforeSecurity =>
      _prefs?.getBool(keyAskBiometricsBeforeSecurity) ?? false;
  Future<bool> setAskBiometricsBeforeSecurity(bool value) async =>
      await _prefs?.setBool(keyAskBiometricsBeforeSecurity, value) ?? false;

  bool get askBiometricsBeforeLogout =>
      _prefs?.getBool(keyAskBiometricsBeforeLogout) ?? false;
  Future<bool> setAskBiometricsBeforeLogout(bool value) async =>
      await _prefs?.setBool(keyAskBiometricsBeforeLogout, value) ?? false;

  Future<void> clearAuthSession() async {
    final String userIdStr = userId;
    await setLoggedIn(false);
    if (userIdStr.isNotEmpty) {
      await _prefs?.remove('synced_session_$userIdStr');
    }
  }

  Future<void> resetAll() async {
    await _prefs?.clear();
  }
}
