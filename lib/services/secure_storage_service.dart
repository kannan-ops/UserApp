import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static SecureStorageService? _instance;
  static SharedPreferences? _prefs;

  SecureStorageService._();

  static Future<SecureStorageService> getInstance() async {
    _instance ??= SecureStorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  String _encrypt(String value) {
    return base64.encode(utf8.encode(value));
  }

  String _decrypt(String encrypted) {
    try {
      return utf8.decode(base64.decode(encrypted));
    } catch (_) {
      return '';
    }
  }

  Future<void> writeSecure(String key, String value) async {
    final String encrypted = _encrypt(value);
    await _prefs?.setString('sec_v2_$key', encrypted);
  }

  String readSecure(String key) {
    final String? encrypted = _prefs?.getString('sec_v2_$key');
    if (encrypted == null || encrypted.isEmpty) return '';
    return _decrypt(encrypted);
  }

  Future<void> writeBoolSecure(String key, bool value) async {
    await writeSecure(key, value ? 'true' : 'false');
  }

  bool readBoolSecure(String key) {
    final String val = readSecure(key);
    return val == 'true';
  }

  Future<void> deleteSecure(String key) async {
    await _prefs?.remove('sec_v2_$key');
  }

  Future<void> clearAllSecure() async {
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith('sec_v2_')) {
        await _prefs?.remove(key);
      }
    }
  }
}
