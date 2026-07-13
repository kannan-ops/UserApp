import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/main.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);
  @override
  String toString() => message;
}

class SecurityAuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = _StorageDebugAdapter();
    final token = await storage.read(key: 'token');

    if (token == null || token.isEmpty) {
      print("ERROR: TOKEN IS EMPTY");
      NavigationService.navigateToLogin();
    }

    final prefs = await SharedPreferences.getInstance();

    if (token == null || token.isEmpty) {
      print("TOKEN NOT FOUND");
    }

    String authHeader = '';
    if (token != null && token.isNotEmpty) {
      authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';
    }

    options.headers["Authorization"] = authHeader;
    options.headers["X-Auth-Token"] = token ?? '';

    options.headers["Accept"] = "application/json";
    options.headers["Content-Type"] = "application/json";
    options.headers["User-Agent"] = "Mozilla/5.0";
    options.headers["Origin"] = "https://user.jobes24x7.com";
    options.headers["Referer"] = "https://user.jobes24x7.com/";
    options.headers["X-Requested-With"] = "XMLHttpRequest";
    options.headers["Cache-Control"] = "no-cache";
    options.headers["Pragma"] = "no-cache";

    final String? storedCookies = prefs.getString('stored_cookies');
    if (storedCookies != null && storedCookies.isNotEmpty) {
      options.headers["Cookie"] = storedCookies;
      print("========== INJECTED COOKIES ==========");
      final String maskedCookies = storedCookies.replaceAll(
        RegExp(r'connect\.sid=[^;]+'),
        'connect.sid=***',
      );
      print(maskedCookies);
    }

    if (options.path.contains('/generate-auth') &&
        !options.path.contains('t=')) {
      final String separator = options.path.contains('?') ? '&' : '?';
      options.path =
          "${options.path}${separator}t=${DateTime.now().millisecondsSinceEpoch}";
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final List<String>? setCookies = response.headers['set-cookie'];
    if (setCookies != null && setCookies.isNotEmpty) {
      final List<String> cookiePairs = [];
      for (var cookie in setCookies) {
        final part = cookie.split(';').first;
        cookiePairs.add(part.trim());
      }
      final String cookiesString = cookiePairs.join('; ');
      final prefs = await SharedPreferences.getInstance();

      String? existing = prefs.getString('stored_cookies');
      if (existing != null && existing.isNotEmpty) {
        final Map<String, String> cookieMap = {};
        for (var pair in existing.split(';')) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            cookieMap[parts[0].trim()] = parts[1].trim();
          }
        }
        for (var pair in cookiesString.split(';')) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            cookieMap[parts[0].trim()] = parts[1].trim();
          }
        }
        final mergedString = cookieMap.entries
            .map((e) => "${e.key}=${e.value}")
            .join('; ');
        await prefs.setString('stored_cookies', mergedString);
      } else {
        await prefs.setString('stored_cookies', cookiesString);
      }
    }

    super.onResponse(response, handler);
  }
}

class SecurityAuthApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://user.jobes24x7.com/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final CookieJar _cookieJar = CookieJar();

  SecurityAuthApiService() {
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(SecurityAuthInterceptor());
    _dio.interceptors.add(ApiDebugLogger.dioInterceptor);
  }

  Future<Map<String, dynamic>> generateSecuritySession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    String authHeader = '';
    if (token != null && token.isNotEmpty) {
      authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';
    }

    const String url = "/generate-auth";

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            "Authorization": authHeader,
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0",
            "Origin": "https://user.jobes24x7.com",
            "Referer": "https://user.jobes24x7.com/",
            "X-Requested-With": "XMLHttpRequest",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
            "X-Auth-Token": token ?? '',
          },
        ),
      );

      final int sessionCode = int.parse(
        response.data['session_code'].toString(),
      );
      final int authId = int.parse(response.data['auth_id'].toString());

      await prefs.setInt('auth_id', authId);
      await prefs.setInt('session_code', sessionCode);

      return {"session_code": sessionCode, "auth_id": authId};
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveAuthConfig({
    required int authId,
    required int selectedNumber,
    required String operation,
  }) async {
    const String path = '/save-auth-config';

    final String mappedOp = operation == '+'
        ? 'plus'
        : (operation == '-' ? 'minus' : operation);

    final Map<String, dynamic> requestBody = {
      "auth_id": authId,
      "selected_number": selectedNumber,
      "operation": mappedOp,
    };

    try {
      final response = await _dio.post(path, data: requestBody);

      final bool success =
          response.statusCode == 200 ||
          (response.data != null && (response.data['result'] == 'Success'));

      final int correctAnswer = int.parse(
        (response.data['correct_answer'] ?? 0).toString(),
      );

      return {
        "success": success,
        "correct_answer": correctAnswer,
        "data": response.data,
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  Future<List<int>> loadVerificationOptions({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    String authHeader = '';
    if (token != null && token.isNotEmpty) {
      authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';
    }

    final String url = "https://user.jobes24x7.com/api/get-auth-options/$id";

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            "Authorization": authHeader,
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
            "X-Auth-Token": token ?? '',
          },
        ),
      );

      List<int> parsedOptions = [];
      if (response.data != null && response.data['options'] != null) {
        parsedOptions = List<int>.from(
          (response.data['options'] as List).map(
            (x) => int.parse(x.toString()),
          ),
        );
      }
      return parsedOptions;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifySelectedOption({
    required int authId,
    required int clickedOption,
  }) async {
    const String path = '/verify-option';
    final Map<String, dynamic> requestBody = {
      "auth_id": authId,
      "clicked_option": clickedOption,
    };

    try {
      final response = await _dio.post(path, data: requestBody);

      final bool success =
          response.statusCode == 200 ||
          (response.data != null &&
              (response.data['success'] == true ||
                  response.data['result'] == 'Success'));

      return {"success": success, "data": response.data};
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyFinalAuth({
    required int authId,
    required int clickedOption,
    required String operation,
    required int selectedNumber,
  }) async {
    const String path = '/verify-auth';

    final String mappedOp = operation == '+'
        ? 'plus'
        : (operation == '-' ? 'minus' : operation);

    final Map<String, dynamic> requestBody = {
      "auth_id": authId,
      "selected_answer": clickedOption,
      "selected_operation": mappedOp,
      "selected_number": selectedNumber,
    };

    try {
      final response = await _dio.post(path, data: requestBody);

      final bool success =
          response.statusCode == 200 &&
          response.data != null &&
          (response.data['result'] == 'Success' ||
              response.data['is_correct'] == 1 ||
              response.data['is_correct'] == true);

      return {"success": success, "data": response.data};
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }
}

class _StorageDebugAdapter {
  Future<void> write({required String key, required dynamic value}) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'token') {
      await prefs.setString('auth_token', value?.toString() ?? '');
    }
  }

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'token') {
      return prefs.getString('auth_token');
    }
    return null;
  }
}
