import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class MessageCentralService {
  static const String customerId = 'C-836DB70B5587493';
  static const String authToken =
      'eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJDLTgzNkRCNzBCNTU4NzQ5MyIsImlhdCI6MTc3MzA0NzU5OSwiZXhwIjoxOTMwNzI3NTk5fQ.pgnC_7IQgwfh3QGRuu4APflRX9VCpt_RQNR-QX1SP425KXn4PUmAohdQTWtEWhDx7Z9lOVfAevCVHCed4uemew';
  static const String _baseUrl = 'https://cpaas.messagecentral.com';

  Future<String?> sendOtp({
    required String countryCode,
    required String mobileNumber,
    required String flowType,
  }) async {
    try {
      final cleanMobile = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');

      final url = Uri.parse(
        '$_baseUrl/verification/v3/send?'
        'countryCode=$countryCode&'
        'customerId=$customerId&'
        'flowType=$flowType&'
        'mobileNumber=$cleanMobile',
      );

      debugPrint(
        'DEBUG [MessageCentral]: Requesting OTP Send to $cleanMobile via $flowType...',
      );
      final response = await ApiDebugLogger.httpClient.post(
        url,
        headers: {'authToken': authToken, 'Content-Type': 'application/json'},
      );

      debugPrint(
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
      debugPrint('DEBUG [MessageCentral]: Error sending OTP: $e');
      return null;
    }
  }

  Future<bool> validateOtp({
    required String countryCode,
    required String mobileNumber,
    required String verificationId,
    required String code,
  }) async {
    try {
      final cleanMobile = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');

      final url = Uri.parse(
        '$_baseUrl/verification/v3/validateOtp?'
        'countryCode=$countryCode&'
        'mobileNumber=$cleanMobile&'
        'verificationId=$verificationId&'
        'customerId=$customerId&'
        'code=$code',
      );

      debugPrint(
        'DEBUG [MessageCentral]: Requesting OTP validation for $verificationId with code $code...',
      );
      final response = await ApiDebugLogger.httpClient.get(
        url,
        headers: {'authToken': authToken},
      );

      debugPrint(
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
      debugPrint('DEBUG [MessageCentral]: Error validating OTP: $e');
      return false;
    }
  }
}

class MailOtpService {
  static const String _smtpHost = 'mail.circuitpoint.in';
  static const String _smtpUser = 'info@circuitpoint.in';
  static const String _smtpPass = 'Cpselvaraj@#16';
  static const int _smtpPort = 465;

  static String? _cachedOtp;
  static String? _cachedEmail;
  static DateTime? _cachedExpiry;

  static Future<bool> sendOtpEmail(String recipientEmail) async {
    try {
      final String code = (100000 + Random().nextInt(900000)).toString();

      final message = Message()
        ..from = const Address(_smtpUser, 'Circuitpoint Secure Vault')
        ..recipients.add(recipientEmail)
        ..subject = 'Circuitpoint Secure Vault - OTP Verification'
        ..text =
            'Your secure authorization OTP code is: $code\n\nThis OTP is valid for 5 minutes. Please do not share this code with anyone.';

      try {
        final smtpServer = SmtpServer(
          _smtpHost,
          username: _smtpUser,
          password: _smtpPass,
          port: _smtpPort,
          ssl: true,
        );
        final sendReport = await send(message, smtpServer);
        debugPrint(
          'DEBUG [MailService]: Email OTP dispatched successfully via Hostname: $sendReport',
        );
      } catch (dnsError) {
        debugPrint(
          'DEBUG [MailService]: Host lookup or SSL error: $dnsError. Retrying with Raw IP fallback...',
        );
        final fallbackServer = SmtpServer(
          '209.142.66.165',
          username: _smtpUser,
          password: _smtpPass,
          port: _smtpPort,
          ssl: true,
          ignoreBadCertificate: true,
        );
        final sendReport = await send(message, fallbackServer);
        debugPrint(
          'DEBUG [MailService]: Email OTP dispatched successfully via Raw IP fallback: $sendReport',
        );
      }

      _cachedOtp = code;
      _cachedEmail = recipientEmail;
      _cachedExpiry = DateTime.now().add(const Duration(minutes: 5));
      return true;
    } catch (e) {
      debugPrint('DEBUG [MailService]: SMTP Error sending email: $e');
      return false;
    }
  }

  static bool validateMailOtp(String email, String enteredCode) {
    if (_cachedOtp == null || _cachedEmail == null || _cachedExpiry == null) {
      debugPrint(
        'DEBUG [MailService]: Verification session expired or not found.',
      );
      return false;
    }

    if (DateTime.now().isAfter(_cachedExpiry!)) {
      debugPrint('DEBUG [MailService]: OTP has expired.');
      return false;
    }

    if (_cachedEmail!.toLowerCase().trim() != email.toLowerCase().trim()) {
      debugPrint('DEBUG [MailService]: Recipient email mismatch.');
      return false;
    }

    final success = _cachedOtp == enteredCode.trim();
    if (success) {
      _cachedOtp = null;
    }
    return success;
  }
}

class OtpService {
  Future<bool> sendOtp(String email) async {
    return await MailOtpService.sendOtpEmail(email);
  }

  bool verifyOtp(String email, String code) {
    return MailOtpService.validateMailOtp(email, code);
  }
}
