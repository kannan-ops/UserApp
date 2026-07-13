import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_security_service.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class SecurityManager {
  static const double _maxAllowedDistanceMeters = 50000;
  static const String _sessionKey = 'user_secure_session';
  static StreamSubscription<Position>? _positionStream;

  static Future<bool> validateSession(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!prefs.containsKey(_sessionKey)) {
      if (isLoggedIn) {
        _showUnauthorized(
          context,
          "Unauthorized Device or Location. Re-verification required.",
        );
        await forceLogout();
        return false;
      }
      return true;
    }

    try {
      final String? sessionData = prefs.getString(_sessionKey);
      if (sessionData == null) {
        await ApiDebugLogger.logSessionInfo(
          eventName: 'SESSION_VALIDATION_EVENT',
          sessionStatus: 'INVALID',
        );
        return false;
      }

      final storedSession = jsonDecode(sessionData);
      final currentPayload = await DeviceSecurityService.getSecurityPayload();

      if (storedSession['device_id'] != currentPayload['device_id']) {
        _showUnauthorized(
          context,
          "Unauthorized Device or Location. App access blocked.",
        );
        await forceLogout();
        await ApiDebugLogger.logSessionInfo(
          eventName: 'SESSION_VALIDATION_EVENT',
          sessionStatus: 'INVALID',
        );
        return false;
      }

      final storedLat = storedSession['latitude'];
      final storedLon = storedSession['longitude'];
      final currentLat = currentPayload['latitude'];
      final currentLon = currentPayload['longitude'];

      if (storedLat != null &&
          storedLon != null &&
          currentLat != null &&
          currentLon != null) {
        final distance = _calculateDistance(
          storedLat,
          storedLon,
          currentLat,
          currentLon,
        );
        if (distance > _maxAllowedDistanceMeters) {
          _showUnauthorized(
            context,
            "Unauthorized Device or Location. Outside allowed area.",
          );
          await forceLogout();
          await ApiDebugLogger.logSessionInfo(
            eventName: 'SESSION_VALIDATION_EVENT',
            sessionStatus: 'INVALID',
          );
          return false;
        }
      }

      await ApiDebugLogger.logSessionInfo(
        eventName: 'SESSION_VALIDATION_EVENT',
        sessionStatus: 'VALID',
      );
      return true;
    } catch (e) {
      debugPrint("Session validation error: $e");
      await ApiDebugLogger.logSessionInfo(
        eventName: 'SESSION_VALIDATION_EVENT',
        sessionStatus: 'INVALID',
      );
      return false;
    }
  }

  static Future<void> createDeviceSession() async {
    final payload = await DeviceSecurityService.getSecurityPayload();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(payload));
  }

  static Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove(_sessionKey);

    await ApiDebugLogger.logSessionInfo(
      eventName: 'LOGOUT_EVENT',
      sessionStatus: 'INVALID',
    );
  }

  static void _showUnauthorized(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double dLat = lat1 - lat2;
    double dLon = lon1 - lon2;
    return (dLat * dLat + dLon * dLon) * 111000;
  }

  static Future<Map<String, String>> getSecurityHeaders() async {
    final payload = await DeviceSecurityService.getSecurityPayload();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    return {
      'Content-Type': 'application/json',
      'X-Device-ID': payload['device_id'].toString(),
      'X-Location-Lat': payload['latitude']?.toString() ?? '',
      'X-Location-Lon': payload['longitude']?.toString() ?? '',
      'X-Location-Address': payload['readable_address']?.toString() ?? '',
      'Authorization': 'Bearer $token',
    };
  }

  static void startLocationMonitoring(
    BuildContext context,
    Function onViolation,
  ) {
    _positionStream?.cancel();

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100,
          ),
        ).listen((Position position) async {
          final prefs = await SharedPreferences.getInstance();
          if (!prefs.containsKey(_sessionKey)) return;

          final String? sessionData = prefs.getString(_sessionKey);
          if (sessionData == null) return;

          final storedSession = jsonDecode(sessionData);
          final storedLat = storedSession['latitude'];
          final storedLon = storedSession['longitude'];

          if (storedLat != null && storedLon != null) {
            final distance = _calculateDistance(
              storedLat,
              storedLon,
              position.latitude,
              position.longitude,
            );
            if (distance > _maxAllowedDistanceMeters) {
              _showUnauthorized(
                context,
                "Unauthorized Location. Outside allowed area.",
              );
              await forceLogout();
              onViolation();
            }
          }
        });
  }

  static void stopLocationMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
