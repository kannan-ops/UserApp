import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class MessageCentralService {
  static const _storage = FlutterSecureStorage();

  static const String _keyCustomerId = 'mc_customer_id';
  static const String _keyPassword = 'mc_password';
  static const String _keyAuthToken = 'mc_auth_token';
  static const String _keyTokenExpiry = 'mc_token_expiry';

  static const String _baseUrl = 'https://cpaas.messagecentral.com';

  Future<void> saveCredentials(String customerId, String password) async {
    await _storage.write(key: _keyCustomerId, value: customerId);
    await _storage.write(key: _keyPassword, value: password);

    await _storage.delete(key: _keyAuthToken);
    await _storage.delete(key: _keyTokenExpiry);
    print('DEBUG [MessageCentral]: Credentials saved securely.');
  }

  Future<String?> getCustomerId() async {
    return await _storage.read(key: _keyCustomerId);
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyCustomerId);
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyAuthToken);
    await _storage.delete(key: _keyTokenExpiry);
  }

  Future<bool> isConfigured() async {
    final customerId = await getCustomerId();
    final password = await _storage.read(key: _keyPassword);
    return customerId != null &&
        customerId.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  String _base64Encode(String input) {
    return base64Encode(utf8.encode(input));
  }

  Future<String?> _getAuthToken() async {
    try {
      final cachedToken = await _storage.read(key: _keyAuthToken);
      final expiryStr = await _storage.read(key: _keyTokenExpiry);

      if (cachedToken != null && expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);

        if (expiry.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
          print('DEBUG [MessageCentral]: Using cached token.');
          return cachedToken;
        }
      }

      final customerId = await _storage.read(key: _keyCustomerId);
      final password = await _storage.read(key: _keyPassword);

      if (customerId == null || password == null) {
        print(
          'DEBUG [MessageCentral]: Missing Customer ID or Password. Falls back to mock.',
        );
        return null;
      }

      final base64Key = _base64Encode(password);
      final url =
          '$_baseUrl/auth/v1/authentication/token?customerId=$customerId&key=$base64Key&scope=NEW';

      print('DEBUG [MessageCentral]: Fetching auth token from API...');
      final response = await ApiDebugLogger.httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token =
            data['token']?.toString() ?? data['data']?['token']?.toString();

        if (token != null) {
          await _storage.write(key: _keyAuthToken, value: token);

          final expiry = DateTime.now().add(const Duration(hours: 23));
          await _storage.write(
            key: _keyTokenExpiry,
            value: expiry.toIso8601String(),
          );

          final maskedToken = token.length > 15
              ? '${token.substring(0, 15)}...'
              : 'TOKEN';
          print(
            'DEBUG [MessageCentral]: Successfully fetched and cached token: $maskedToken',
          );
          return token;
        }
      }

      print(
        'DEBUG [MessageCentral]: Token request failed with status: ${response.statusCode}',
      );
      return null;
    } catch (e) {
      print('DEBUG [MessageCentral]: Error fetching token: $e');
      return null;
    }
  }

  Future<String?> sendOtp({
    required String countryCode,
    required String contact,
    required String flowType,
  }) async {
    final configured = await isConfigured();
    if (!configured) {
      final mockVerificationId =
          'mock_verif_${DateTime.now().millisecondsSinceEpoch}';
      print(
        'DEBUG [MessageCentral SIMULATION]: Simulated OTP sent via $flowType to $countryCode$contact. Mock ID: $mockVerificationId',
      );
      return mockVerificationId;
    }

    try {
      final token = await _getAuthToken();
      final customerId = await getCustomerId();

      if (token == null || customerId == null) {
        print(
          'DEBUG [MessageCentral]: Auth token failed. Falling back to simulated flow.',
        );
        return 'mock_verif_fallback_${DateTime.now().millisecondsSinceEpoch}';
      }

      final url = Uri.parse(
        '$_baseUrl/verification/v3/send?'
        'countryCode=$countryCode&'
        'mobileNumber=$contact&'
        'flowType=$flowType&'
        'customerId=$customerId',
      );

      print(
        'DEBUG [MessageCentral]: Requesting OTP Send to $contact via $flowType...',
      );
      final response = await ApiDebugLogger.httpClient.post(
        url,
        headers: {'authToken': token, 'Content-Type': 'application/json'},
      );

      print(
        'DEBUG [MessageCentral]: Send OTP Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final verificationId =
            data['verificationId']?.toString() ??
            data['data']?['verificationId']?.toString();
        return verificationId;
      }
      return null;
    } catch (e) {
      print('DEBUG [MessageCentral]: Error sending OTP: $e');
      return null;
    }
  }

  Future<bool> validateOtp({
    required String verificationId,
    required String code,
  }) async {
    if (verificationId.startsWith('mock_verif_')) {
      final isSimulatedSuccess = code == '123456' || code == '654321';
      print(
        'DEBUG [MessageCentral SIMULATION]: Validated mock OTP "$code". Result: $isSimulatedSuccess',
      );
      return isSimulatedSuccess;
    }

    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('DEBUG [MessageCentral]: Auth token unavailable for validation.');
        return false;
      }

      final url = Uri.parse(
        '$_baseUrl/verification/v3/validateOtp?'
        'verificationId=$verificationId&'
        'code=$code',
      );

      print(
        'DEBUG [MessageCentral]: Requesting OTP validation for $verificationId with code $code...',
      );
      final response = await ApiDebugLogger.httpClient.get(
        url,
        headers: {'authToken': token},
      );

      print(
        'DEBUG [MessageCentral]: Validate OTP Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final responseCode =
            data['responseCode']?.toString() ?? data['code']?.toString();
        return responseCode == '200' ||
            response.body.toLowerCase().contains('success');
      }
      return false;
    } catch (e) {
      print('DEBUG [MessageCentral]: Error validating OTP: $e');
      return false;
    }
  }
}
