import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:enquiry_app/services/security_auth_api_service.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class GridCardApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://user.jobes24x7.com/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  GridCardApiService() {
    _dio.interceptors.add(SecurityAuthInterceptor());
    _dio.interceptors.add(ApiDebugLogger.dioInterceptor);
    final cookieJar = CookieJar();
    _dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<Map<String, dynamic>> generateGridCard({
    required String userMainId,
  }) async {
    const String path = '/grid-card/generate';
    final Map<String, dynamic> requestBody = {"user_main_id": userMainId};

    try {
      final response = await _dio.post(path, data: requestBody);

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyGridCard({
    required String userMainId,
    required List<String> challenges,
    required List<String> answers,
  }) async {
    const String path = '/grid-card/verify';
    final Map<String, dynamic> requestBody = {
      "user_main_id": userMainId,
      "challenges": challenges,
      "answers": answers,
    };

    try {
      final response = await _dio.post(path, data: requestBody);

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw SessionExpiredException('Session expired. Please login again.');
      }
      rethrow;
    }
  }
}
