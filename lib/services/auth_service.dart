import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/services/security_service.dart';

class NewDeviceDetectedException implements Exception {
  final String message;
  NewDeviceDetectedException(this.message);
  @override
  String toString() => message;
}

class InvalidCredentialsException implements Exception {
  final String message;
  InvalidCredentialsException(this.message);
  @override
  String toString() => message;
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final StorageService _storageService;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  AuthService(this._storageService) {
    _dio.interceptors.add(ApiDebugLogger.dioInterceptor);
  }

  Future<bool> login(String email, String password) async {
    const String url = "https://user.jobes24x7.com/api/login/authenticate";

    final deviceInfo = DeviceInfoPlugin();
    String deviceId = "unknown_device_id";
    String deviceName = "unknown_device_name";
    String platform = "unknown";

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.model;
        platform = "android";
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "unknown_ios_id";
        deviceName = iosInfo.name;
        platform = "ios";
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
        deviceName = windowsInfo.computerName;
        platform = "windows";
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo macosInfo = await deviceInfo.macOsInfo;
        deviceId = macosInfo.systemGUID ?? "unknown_macos_id";
        deviceName = macosInfo.computerName;
        platform = "macos";
      } else {
        platform = Platform.operatingSystem;
      }
    } catch (e) {
      print("Error getting device info: $e");
    }

    print("DEVICE ID: $deviceId");
    print("DEVICE NAME: $deviceName");
    print("PLATFORM: $platform");

    try {
      final response = await _dio.post(
        url,
        data: {"email": email, "password": password},
      );

      print("========== LOGIN REQUEST COMPLETED ==========");

      final responseStr = response.toString();
      if (responseStr.contains("New device detected")) {
        print("NEW DEVICE DETECTED RESPONSE RECEIVED");
        throw NewDeviceDetectedException("New device detected");
      }

      if (response.statusCode == 200) {
        print("LOGIN SUCCESS");
        await _storageService.setUserDeviceId(deviceId);

        final storage = _StorageDebugAdapter(_storageService);

        final responseData = jsonDecode(response.body);

        print("========== FULL RESPONSE ==========");
        print(responseData);

        final outerData = responseData['data'];

        print("========== OUTER DATA ==========");
        print(outerData);

        final loginData = outerData['data'];

        print("========== INNER LOGIN DATA ==========");
        print(loginData);

        final int? id = loginData['id'];

        final String email = loginData['email']?.toString() ?? '';

        final String userName = loginData['user_name']?.toString() ?? '';

        final String userMainId = loginData['user_main_id']?.toString() ?? '';

        final String virtualId = loginData['virtual_id']?.toString() ?? '';

        final String userType = loginData['user_type']?.toString() ?? '';

        print("========== FIXED LOGIN RESPONSE ==========");

        print("ID: $id");
        print("EMAIL: $email");
        print("USERNAME: $userName");
        print("USER MAIN ID: $userMainId");
        print("VIRTUAL ID: $virtualId");
        print("USER TYPE: $userType");

        final String? token = outerData['token']?.toString();
        if (token != null) {
          await storage.write(key: 'token', value: token);
          await _storageService.setAuthToken(token);
        }

        final List<String>? setCookies = response.headers['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          final List<String> cookiePairs = [];
          for (var cookie in setCookies) {
            final part = cookie.split(';').first;
            cookiePairs.add(part.trim());
          }
          final String cookiesString = cookiePairs.join('; ');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('stored_cookies', cookiesString);
          print("========== LOGIN COOKIES STORED ==========");
          final String maskedCookies = cookiesString.replaceAll(
            RegExp(r'connect\.sid=[^;]+'),
            'connect.sid=***',
          );
          print(maskedCookies);
        }

        await _storageService.setLoggedIn(true);
        await _storageService.setUserRole(
          userType.isNotEmpty ? userType : 'user',
        );

        if (userMainId.isNotEmpty) {
          await _storageService.setUserId(userMainId);
        }
        await _storageService.setUserName(
          userName.isNotEmpty ? userName : (email.isNotEmpty ? email.split('@').first : ''),
        );
        await _storageService.setUserEmail(email);

        final now = DateTime.now();
        final formattedDate =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
        await _storageService.setUserLastLogin(formattedDate);

        ApiDebugLogger.logSessionInfo(
          eventName: 'LOGIN_EVENT',
          sessionStatus: 'VALID',
        );

        // Fetch profile details immediately to cache phone number
        try {
          final prefs = await SharedPreferences.getInstance();
          final String? savedCookies = prefs.getString('stored_cookies');
          final String profileUrl = "https://user.jobes24x7.com/api/login/$userMainId";
          final Map<String, String> headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
            if (savedCookies != null && savedCookies.isNotEmpty) 'Cookie': savedCookies,
          };
          final profileResponse = await _dio.get(
            profileUrl,
            options: Options(headers: headers),
          );
          if (profileResponse.statusCode == 200) {
            final Map<String, dynamic> json = profileResponse.data is Map
                ? profileResponse.data
                : jsonDecode(profileResponse.data.toString());
            final rawData = json['data'];
            Map<String, dynamic> userDetails = {};
            if (rawData is Map) {
              if (rawData.containsKey('data') && rawData['data'] is Map) {
                userDetails = Map<String, dynamic>.from(rawData['data']);
              } else {
                userDetails = Map<String, dynamic>.from(rawData);
              }
            } else if (json['user'] is Map) {
              userDetails = Map<String, dynamic>.from(json['user']);
            }
            if (userDetails.isNotEmpty) {
              final String phone = userDetails['phone_number']?.toString() ??
                  userDetails['phone']?.toString() ?? '';
              if (phone.isNotEmpty) {
                await _storageService.setUserPhone(phone);
              }
            }
          }
        } catch (e) {
          print("Error fetching profile on login: $e");
        }

        return true;
      } else {
        print("LOGIN FAILED");
        return false;
      }
    } on DioException catch (e) {
      final responseStr = e.response?.toString() ?? '';
      if (responseStr.contains("New device detected")) {
        print("NEW DEVICE DETECTED RESPONSE RECEIVED (DioException)");
        throw NewDeviceDetectedException("New device detected");
      }

      print("========== LOGIN API ==========");
      print("EMAIL: $email");
      print("STATUS CODE: ${e.response?.statusCode}");
      print("RESPONSE: ${e.response?.data}");

      if (e.response?.statusCode == 401) {
        print("INVALID CREDENTIALS");
        print("LOGIN FAILED");
        throw InvalidCredentialsException("Wrong email or password.");
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        print("LOGIN FAILED");
        throw NoInternetException(
          "No internet connection. Please check your network.",
        );
      } else {
        print("LOGIN FAILED");
        throw Exception("An unexpected error occurred: ${e.message}");
      }
    } catch (e) {
      print("========== LOGIN API ==========");
      print("EMAIL: $email");
      print("LOGIN FAILED");
      throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<bool> checkUserExists(String email) async {
    final String url =
        "https://user.jobes24x7.com/api/login/check-email/${Uri.encodeComponent(email)}";
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null) {
          return data['data']['exists'] == true;
        }
      }
      return false;
    } catch (e) {
      print("Error in checkUserExists: $e");
      rethrow;
    }
  }

  Future<bool> registerUser(
    String email,
    String password, {
    String? userName,
    String? address,
  }) async {
    const String url = "https://user.jobes24x7.com/api/login/create";
    try {
      final response = await _dio.post(
        url,
        data: {
          "email": email,
          "password": password,
          "email_otp": false,
          "mobile_otp": false,
          "status": 1,
          "is_verified": 1,
          "created_by": "user",
          "user_type": "guest",
          "user_name": userName ?? email.split('@').first,
          if (address != null) "address": address,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null) {
          final resultData = data['data'];
          if (resultData['result'] == 'Success' || resultData['code'] == 200) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print("Error in registerUser: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storageService.clearAuthSession();
    SecurityManager.resetInitialization();
    SecurityService.resetSessionHistoryState();

    await ApiDebugLogger.logSessionInfo(
      eventName: 'LOGOUT_EVENT',
      sessionStatus: 'INVALID',
    );
  }

  Future<bool> isBiometricHardwareAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return <BiometricType>[];
    }
  }

  Future<bool> authenticateWithBiometrics({required String reason}) async {
    try {
      final isHardwareAvailable = await isBiometricHardwareAvailable();
      if (!isHardwareAvailable) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}

class _StorageDebugAdapter {
  final StorageService? _storageService;
  _StorageDebugAdapter([this._storageService]);

  Future<void> write({required String key, required dynamic value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', value?.toString() ?? '');
    if (_storageService != null) {
      await _storageService.setAuthToken(value?.toString() ?? '');
    }
  }

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}

extension ResponseDebugExtension on Response {
  String get body => data is String ? data : jsonEncode(data);
}
