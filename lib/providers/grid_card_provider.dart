import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/models/grid_card_model.dart';
import 'package:enquiry_app/services/grid_card_api_service.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/services/security_service.dart';

class GridCardProvider extends ChangeNotifier {
  final GridCardApiService _apiService = GridCardApiService();

  GridCardModel? _gridCard;
  bool _isLoading = false;
  List<String> _currentChallenge = [];
  bool _isVerified = false;
  String? _errorMessage;

  final Map<String, TextEditingController> _controllers = {};

  GridCardModel? get gridCard => _gridCard;
  bool get isCardGenerated => _gridCard != null;
  bool get isLoading => _isLoading;
  List<String> get currentChallenge => _currentChallenge;
  bool get isVerified => _isVerified;
  String? get errorMessage => _errorMessage;
  Map<String, TextEditingController> get controllers => _controllers;

  GridCardProvider() {
    _loadPersistedGridCard();
  }

  Future<void> _loadPersistedGridCard() async {
    final prefs = await SharedPreferences.getInstance();
    _isVerified = prefs.getBool('grid_card_verified') ?? false;
    final String? savedCard = prefs.getString('stored_grid_card');
    if (savedCard != null && savedCard.isNotEmpty) {
      try {
        _gridCard = GridCardModel.fromJson(jsonDecode(savedCard));
        print("========== LOADED PERSISTED GRID CARD ==========");
        print("CARD SERIAL: ${_gridCard!.cardSerialNumber}");

        if (_currentChallenge.isEmpty || _controllers.isEmpty) {
          generateChallenge();
        }
      } catch (e) {
        print("Failed parsing saved grid card: $e");
      }
    }
    notifyListeners();
  }

  Future<bool> generateGridCard(String userMainId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.generateGridCard(
        userMainId: userMainId,
      );

      final dynamic root = response['data'] ?? response;
      final dynamic inner = root['data'] ?? root;
      final String cardSerialNumber = (inner['card_serial_number'] ?? '')
          .toString();
      final Map gridRaw = inner['grid_data'] as Map? ?? {};

      print("CARD SERIAL: $cardSerialNumber");
      print("GRID DATA: $gridRaw");

      _gridCard = GridCardModel.fromJson(response);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'stored_grid_card',
        jsonEncode(_gridCard!.toJson()),
      );

      generateChallenge();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Failed to generate Grid Card. Try again.";
      notifyListeners();
      return false;
    }
  }

  void generateChallenge() {
    final List<String> columns = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
    final List<String> rows = ['1', '2', '3', '4', '5'];
    final List<String> allCoordinates = [];

    for (var col in columns) {
      for (var row in rows) {
        allCoordinates.add('$col$row');
      }
    }

    allCoordinates.shuffle();
    _currentChallenge = allCoordinates.take(3).toList();

    _controllers.forEach((k, v) => v.dispose());
    _controllers.clear();
    for (var coord in _currentChallenge) {
      _controllers[coord] = TextEditingController();
    }

    print("========== GENERATED CHALLENGE ==========");
    print("Coordinates: $_currentChallenge");
    notifyListeners();
  }

  Future<bool> verifyGrid({
    required String userMainId,
    required List<String> challenges,
    required List<String> answers,
  }) async {
    if (_gridCard == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.verifyGridCard(
        userMainId: userMainId,
        challenges: challenges,
        answers: answers,
      );

      final dynamic root = response['data'] ?? response;
      final dynamic inner = root['data'] ?? root;
      final bool success =
          inner['verified'] == true ||
          (root['result'] ?? '').toString().toLowerCase() == 'success';

      if (success) {
        print("========== GRID VERIFIED SUCCESSFULLY ==========");
        _isVerified = true;

        SecurityService(
          ApiService(),
        ).saveLoginHistory(userId: 1, method: 'grid_card').catchError((err) {
          print(
            'DEBUG [GridCardProvider]: Failed saving grid card history: $err',
          );
          return <String, dynamic>{};
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('grid_card_verified', true);
        await prefs.setBool('grid_lock_enabled', true);
      } else {
        print("AUTHENTICATION FAILED");
        _isVerified = false;
        generateChallenge();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Network validation error occurred.";
      notifyListeners();
      return false;
    }
  }

  void logBackNavigation() {
    final Map<String, String> enteredValues = {};
    _controllers.forEach((k, v) {
      enteredValues[k] = v.text;
    });

    print("========== BACK NAVIGATION ==========");
    print("Preserving entered values");

    print("========== CURRENT INPUTS ==========");
    print(enteredValues);

    print("========== GENERATED COORDINATES ==========");
    print(_currentChallenge);
  }

  Future<void> deleteGridCard() async {
    _gridCard = null;
    _isVerified = false;
    _currentChallenge = [];

    _controllers.forEach((k, v) => v.dispose());
    _controllers.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('stored_grid_card');
    await prefs.remove('grid_card_verified');
    await prefs.remove('grid_lock_enabled');
    notifyListeners();
  }

  @override
  void dispose() {
    _controllers.forEach((k, v) => v.dispose());
    super.dispose();
  }
}
