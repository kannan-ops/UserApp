import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/secure_storage_service.dart';

class ApiDebugLogger {
  static final http.Client httpClient = LoggingHttpClient(http.Client());

  static final Interceptor dioInterceptor = ApiDebugInterceptor();

  static void _print(String message) {
    // Disabled all console logging for request/response, headers, payloads, body, session data.
  }

  static http.Client wrapClient(http.Client client) {
    return LoggingHttpClient(client);
  }

  static void logRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    required dynamic body,
  }) {
    // Disabled
  }

  static String _getStatusText(int code) {
    switch (code) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 202:
        return 'Accepted';
      case 204:
        return 'No Content';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 409:
        return 'Conflict';
      case 500:
        return 'Internal Server Error';
      default:
        return 'HTTP $code';
    }
  }

  static void logResponse({
    required String url,
    required int statusCode,
    required dynamic responseBody,
    required Map<String, String> headers,
    required Duration? duration,
    String? statusText,
  }) {
    // Disabled
  }

  static void logError({
    required String url,
    required int? statusCode,
    required String message,
    required dynamic errorResponse,
    required StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    if (statusCode == null || statusCode >= 500) {
      // Print only unexpected exceptions/critical server errors
      print('[CRITICAL API ERROR] URL: $url | Message: $message');
      if (stackTrace != null) {
        print(stackTrace.toString());
      }
    }
  }

  static Future<void> logSessionInfo({
    String? eventName,
    String? sessionStatus,
  }) async {
    // Disabled
  }

  static String _stringifyBody(dynamic body) {
    if (body == null) return 'null';
    if (body is String) return body;
    try {
      return jsonEncode(body);
    } catch (_) {
      return body.toString();
    }
  }
}

class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;
  LoggingHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();

    dynamic requestBody;
    if (request is http.Request) {
      requestBody = request.body;
    } else {
      requestBody = "streamed body";
    }

    ApiDebugLogger.logRequest(
      method: request.method,
      url: request.url.toString(),
      headers: request.headers,
      body: requestBody,
    );

    try {
      final streamedResponse = await _inner.send(request);
      final bytes = await streamedResponse.stream.toBytes();
      final responseBodyString = utf8.decode(bytes, allowMalformed: true);
      final endTime = DateTime.now();

      if (streamedResponse.statusCode >= 400) {
        ApiDebugLogger.logError(
          url: request.url.toString(),
          statusCode: streamedResponse.statusCode,
          message:
              streamedResponse.reasonPhrase ??
              "HTTP Error ${streamedResponse.statusCode}",
          errorResponse: responseBodyString,
          stackTrace: null,
        );
      } else {
        ApiDebugLogger.logResponse(
          url: request.url.toString(),
          statusCode: streamedResponse.statusCode,
          responseBody: responseBodyString,
          headers: streamedResponse.headers,
          duration: endTime.difference(startTime),
        );
      }

      return http.StreamedResponse(
        Stream.value(bytes),
        streamedResponse.statusCode,
        contentLength: streamedResponse.contentLength,
        request: request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } catch (e, stackTrace) {
      ApiDebugLogger.logError(
        url: request.url.toString(),
        statusCode: null,
        message: e.toString(),
        errorResponse: null,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

class ApiDebugInterceptor extends Interceptor {
  final Map<RequestOptions, DateTime> _startTimes = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _startTimes[options] = DateTime.now();
    ApiDebugLogger.logRequest(
      method: options.method,
      url: options.uri.toString(),
      headers: options.headers.map((k, v) => MapEntry(k, v.toString())),
      body: options.data,
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = _startTimes.remove(response.requestOptions);
    final duration = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    if (response.statusCode != null && response.statusCode! >= 400) {
      ApiDebugLogger.logError(
        url: response.requestOptions.uri.toString(),
        statusCode: response.statusCode,
        message: response.statusMessage ?? "HTTP Error ${response.statusCode}",
        errorResponse: response.data,
        stackTrace: null,
      );
    } else {
      ApiDebugLogger.logResponse(
        url: response.requestOptions.uri.toString(),
        statusCode: response.statusCode ?? 0,
        responseBody: response.data,
        headers: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
        duration: duration,
      );
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _startTimes.remove(err.requestOptions);

    ApiDebugLogger.logError(
      url: err.requestOptions.uri.toString(),
      statusCode: err.response?.statusCode,
      message: err.message ?? err.toString(),
      errorResponse: err.response?.data,
      stackTrace: err.stackTrace,
    );
    super.onError(err, handler);
  }
}
