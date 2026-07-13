import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/security_auth_api_service.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/services/security_service.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class SecurityAuthProvider extends ChangeNotifier {
  final SecurityAuthApiService _apiService = SecurityAuthApiService();

  int? _authId;
  int? _sessionCode;
  int _selectedNumber = 3;
  String _operation = '+';
  List<int> _verificationOptions = [];
  int? _userSelectedOption;
  int? _correctAnswer;

  bool _isLoading = false;
  bool _isOptionVerified = false;
  bool _isFormulaStepActive = false;
  bool _isAuthCompleted = false;
  bool _optionVerificationFailed = false;
  bool _isSessionExpired = false;
  String? _errorMessage;

  int? get authId => _authId;
  int? get sessionCode => _sessionCode;
  int get selectedNumber => _selectedNumber;
  String get operation => _operation;
  List<int> get verificationOptions => _verificationOptions;
  int? get userSelectedOption => _userSelectedOption;
  int? get correctAnswer => _correctAnswer;
  bool get isLoading => _isLoading;
  bool get isOptionVerified => _isOptionVerified;
  bool get isFormulaStepActive => _isFormulaStepActive;
  bool get isAuthCompleted => _isAuthCompleted;
  bool get optionVerificationFailed => _optionVerificationFailed;
  bool get isSessionExpired => _isSessionExpired;
  String? get errorMessage => _errorMessage;

  int get calculatedValue {
    if (_sessionCode == null) return 0;
    if (_operation == '+') {
      return _sessionCode! + _selectedNumber;
    } else {
      return _sessionCode! - _selectedNumber;
    }
  }

  String get reverseOperation => _operation == '+' ? '-' : '+';

  Future<void> loadNewSession() async {
    _isLoading = true;
    _errorMessage = null;
    _isOptionVerified = false;
    _isFormulaStepActive = false;
    _isAuthCompleted = false;
    _optionVerificationFailed = false;
    _isSessionExpired = false;
    _userSelectedOption = null;
    _correctAnswer = null;
    _verificationOptions = [];
    notifyListeners();

    try {
      final Map<String, dynamic> result = await _apiService
          .generateSecuritySession();
      _sessionCode = result['session_code'];
      _authId = result['auth_id'];

      _isLoading = false;
      notifyListeners();
    } on SessionExpiredException catch (_) {
      _isLoading = false;
      _isSessionExpired = true;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'API Error: Failed to generate session code.';
      print("FAILED");
      notifyListeners();
    }
  }

  Future<void> refreshSession() async {
    final int? oldSessionCode = _sessionCode;

    _authId = null;
    _sessionCode = null;
    _selectedNumber = 3;
    _operation = '+';
    _verificationOptions = [];
    _userSelectedOption = null;
    _correctAnswer = null;
    _isOptionVerified = false;
    _isFormulaStepActive = false;
    _isAuthCompleted = false;
    _optionVerificationFailed = false;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> result = await _apiService
          .generateSecuritySession();
      _sessionCode = result['session_code'];
      _authId = result['auth_id'];

      print("========== REFRESH SESSION ==========");
      print("Old Session: $oldSessionCode");
      print("New Session: $_sessionCode");
      print("AUTH ID: $_authId");
      print("SESSION CODE: $_sessionCode");

      await ApiDebugLogger.logSessionInfo(
        eventName: 'AUTHENTICATION_REFRESH_EVENT',
        sessionStatus: 'VALID',
      );

      _isLoading = false;
      notifyListeners();
    } on SessionExpiredException catch (_) {
      _isLoading = false;
      _isSessionExpired = true;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'API Error: Failed to generate session code.';
      print("FAILED");
      notifyListeners();
    }
  }

  void setOperation(String op) {
    _operation = op;
    notifyListeners();
  }

  void setSelectedNumber(int num) {
    _selectedNumber = num;
    notifyListeners();
  }

  Future<void> saveConfiguration() async {
    if (_authId == null) return;

    _isLoading = true;
    _errorMessage = null;
    _verificationOptions = [];
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiService.saveAuthConfig(
        authId: _authId!,
        selectedNumber: _selectedNumber,
        operation: _operation,
      );

      final bool success = response['success'] ?? false;
      _correctAnswer = response['correct_answer'];

      if (success) {
        await loadOptions();
      } else {
        _isLoading = false;
        _errorMessage =
            'API Error: Failed to save authentication configuration.';
        notifyListeners();
      }
    } on SessionExpiredException catch (_) {
      _isLoading = false;
      _isSessionExpired = true;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'API Error: Save configuration request failed.';
      notifyListeners();
    }
  }

  Future<void> loadOptions() async {
    if (_authId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _verificationOptions = await _apiService.loadVerificationOptions(
        id: _authId!,
      );
      _isLoading = false;
      notifyListeners();
    } on SessionExpiredException catch (_) {
      _isLoading = false;
      _isSessionExpired = true;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'API Error: Failed to load verification options.';
      notifyListeners();
    }
  }

  Future<void> selectOption(int clickedValue) async {
    if (_authId == null) return;

    _userSelectedOption = clickedValue;
    _isLoading = true;
    _optionVerificationFailed = false;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiService
          .verifySelectedOption(authId: _authId!, clickedOption: clickedValue);

      final bool success = response['success'] ?? false;

      if (success) {
        _isOptionVerified = true;
        _isFormulaStepActive = true;
        _optionVerificationFailed = false;
        _errorMessage = null;
      } else {
        _isOptionVerified = false;
        _isFormulaStepActive = false;
        _optionVerificationFailed = true;
        _errorMessage = 'Incorrect option selected!';
      }
      _isLoading = false;
      notifyListeners();
    } on SessionExpiredException catch (_) {
      _isLoading = false;
      _isSessionExpired = true;
      notifyListeners();
    } catch (e) {
      _isOptionVerified = false;
      _isFormulaStepActive = false;
      _optionVerificationFailed = true;
      _errorMessage = 'API verification error occurred.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyReverseFormula({
    required String selectedOp,
    required int selectedNum,
  }) async {
    if (_userSelectedOption == null || _authId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.verifyFinalAuth(
        authId: _authId!,
        clickedOption: _userSelectedOption!,
        operation: _operation,
        selectedNumber: _selectedNumber,
      );

      final bool success = result['success'] ?? false;

      if (success) {
        SecurityService(
          ApiService(),
        ).saveLoginHistory(userId: 1, method: 'security_tab').catchError((err) {
          print(
            'DEBUG [SecurityAuthProvider]: Failed saving security tab history: $err',
          );
          return <String, dynamic>{};
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sec_tab_auth_verified', true);
        _isAuthCompleted = true;
        _errorMessage = null;
      } else {
        _errorMessage = 'Authentication verification rejected by server.';
        await loadNewSession();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } on SessionExpiredException catch (_) {
      _isLoading = false;
      _isSessionExpired = true;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network validation error occurred.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearSessionExpired() {
    _isSessionExpired = false;
    notifyListeners();
  }
}
