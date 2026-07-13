import 'package:flutter/material.dart';
import 'package:enquiry_app/services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storageService;
  late bool _isDarkMode;

  ThemeProvider(this._storageService) {
    _isDarkMode = _storageService.isDarkMode;
  }

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}
