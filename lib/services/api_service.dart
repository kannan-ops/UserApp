import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/config/api_config.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(super.message);
}

class ApiTimeoutException extends ApiException {
  ApiTimeoutException(super.message);
}

class ServerException extends ApiException {
  ServerException(super.message, int statusCode, dynamic body)
    : super(statusCode: statusCode, body: body);
}

class InvalidResponseException extends ApiException {
  InvalidResponseException(super.message);
}

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  String get baseUrl {
    String base = ApiConfig.baseUrl;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  final Duration timeoutDuration = const Duration(seconds: 15);

  final Map<String, Future<dynamic>> _inFlightRequests = {};

  final Map<String, dynamic> _responseCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheExpiry = const Duration(minutes: 5);

  String _generateRequestKey(String method, String path, dynamic body) {
    final String bodyStr = body != null ? jsonEncode(body) : '';
    return '$method:$path:$bodyStr';
  }

  Future<dynamic> request({
    required String path,
    required String method,
    Map<String, String>? headers,
    dynamic body,
    String? customBaseUrl,
  }) async {
    final String key = _generateRequestKey(method, path, body);
    final DateTime startTime = DateTime.now();

    if (method.toUpperCase() == 'GET' && _responseCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        print("[API DEBUG - DUPLICATE CACHE HIT] Time: $startTime");
        print("Serving cached response for $method $path");
        return _responseCache[key];
      }
    }

    if (_inFlightRequests.containsKey(key)) {
      print("[API DEBUG - CONCURRENT COLLAPSE DETECTED] Time: $startTime");
      print("Collapsing duplicate request for $method $path");
      return _inFlightRequests[key]!;
    }

    print("[API DEBUG - START] Method: $method, Path: $path, Time: $startTime");

    final Future<dynamic> future =
        _executeRequest(
              path: path,
              method: method,
              headers: headers,
              body: body,
              startTime: startTime,
              customBaseUrl: customBaseUrl,
            )
            .then((result) {
              final DateTime endTime = DateTime.now();
              print(
                "[API DEBUG - SUCCESS] Method: $method, Path: $path, End Time: $endTime, Duration: ${endTime.difference(startTime).inMilliseconds}ms",
              );
              if (method.toUpperCase() == 'GET') {
                _responseCache[key] = result;
                _cacheTimestamps[key] = DateTime.now();
              }
              return result;
            })
            .catchError((err) {
              final DateTime endTime = DateTime.now();
              print(
                "[API DEBUG - ERROR] Method: $method, Path: $path, End Time: $endTime, Duration: ${endTime.difference(startTime).inMilliseconds}ms, Error: $err",
              );
              throw err;
            })
            .whenComplete(() {
              _inFlightRequests.remove(key);
            });

    _inFlightRequests[key] = future;
    return future;
  }

  Future<dynamic> _executeRequest({
    required String path,
    required String method,
    Map<String, String>? headers,
    dynamic body,
    required DateTime startTime,
    String? customBaseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      print("ApiService WARNING: TOKEN IS EMPTY");
    }

    String cleanPath = path;
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }

    String activeBase;
    if (customBaseUrl != null) {
      activeBase = customBaseUrl.endsWith('/')
          ? customBaseUrl.substring(0, customBaseUrl.length - 1)
          : customBaseUrl;
    } else {
      activeBase = baseUrl;
    }

    if (cleanPath.contains('/security/update-settings')) {
      activeBase = 'https://lockscreen.srivagroups.in/api';
      final String remaining = cleanPath.substring(cleanPath.indexOf('/security/update-settings') + '/security/update-settings'.length);
      final String trimmedId = remaining.replaceAll('/', '').trim();
      if (trimmedId.isNotEmpty && trimmedId != '8227647092') {
        cleanPath = '/security/update-settings/$trimmedId';
      } else {
        final prefs = await SharedPreferences.getInstance();
        final String phone = prefs.getString('user_phone') ?? '';
        final String userId = prefs.getString('user_id') ?? '';
        final String identifier = phone.isNotEmpty ? phone : (userId.isNotEmpty ? userId : '8227647092');
        cleanPath = '/security/update-settings/$identifier';
      }
    }

    final Uri uri = Uri.parse('$activeBase$cleanPath');

    final Map<String, String> requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    final int maxAttempts = (method.toUpperCase() == 'GET') ? 2 : 1;
    const Duration retryDelay = Duration(milliseconds: 100);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = ApiDebugLogger.wrapClient(http.Client());
      try {
        final Future<http.Response> responseFuture;

        switch (method.toUpperCase()) {
          case 'GET':
            responseFuture = client.get(uri, headers: requestHeaders);
            break;
          case 'POST':
            responseFuture = client.post(
              uri,
              headers: requestHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            responseFuture = client.put(
              uri,
              headers: requestHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            responseFuture = client.delete(
              uri,
              headers: requestHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          default:
            throw ApiException('Unsupported HTTP method: $method');
        }

        final response = await responseFuture.timeout(
          timeoutDuration,
          onTimeout: () {
            client.close();
            throw TimeoutException(
              'Request timed out after ${timeoutDuration.inSeconds} seconds',
            );
          },
        );

        return _handleResponse(response);
      } on SocketException catch (e) {
        print(
          "[API DEBUG - SOCKET EXCEPTION] Attempt $attempt failed: ${e.message}",
        );
        client.close();
        if (attempt >= maxAttempts) {
          throw NetworkException(
            'Server Unreachable: Connection failed. Please verify that the Node.js backend is running properly.',
          );
        }
        await Future.delayed(retryDelay);
      } on TimeoutException catch (e) {
        final DateTime errorTime = DateTime.now();
        print(
          "[API DEBUG - TIMEOUT SOURCE] Attempt $attempt failed. Timeout Duration: ${errorTime.difference(startTime).inSeconds}s, Error: $e",
        );
        client.close();
        if (attempt >= maxAttempts) {
          throw ApiTimeoutException(
            'Connection Timeout: The server took too long to respond.',
          );
        }
        await Future.delayed(retryDelay);
      } catch (e) {
        print("[API DEBUG - GENERIC FAILURE] Attempt $attempt failed: $e");
        client.close();
        if (attempt >= maxAttempts) {
          if (e is ApiException) {
            rethrow;
          }
          throw ApiException('Communication error occurred: $e');
        }
        await Future.delayed(retryDelay);
      }
    }

    throw ApiException(
      'Request failed to complete after $maxAttempts attempts',
    );
  }

  dynamic _handleResponse(http.Response response) {
    final int statusCode = response.statusCode;

    dynamic responseBody;
    if (response.body.isNotEmpty) {
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        throw InvalidResponseException(
          'Malformed Response: The backend returned an invalid JSON schema.',
        );
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return responseBody;
    } else if (statusCode >= 500) {
      throw ServerException(
        'Server Error: Node.js backend encountered a critical error (Status $statusCode).',
        statusCode,
        responseBody,
      );
    } else {
      final String errorMessage =
          responseBody != null && responseBody['message'] != null
          ? responseBody['message'].toString()
          : (responseBody != null && responseBody['error'] != null
                ? responseBody['error'].toString()
                : 'Action failed: Server returned code $statusCode');
      throw ApiException(
        errorMessage,
        statusCode: statusCode,
        body: responseBody,
      );
    }
  }
}
