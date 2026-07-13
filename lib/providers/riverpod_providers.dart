import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/services/secure_storage_service.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/repositories/lock_repository.dart';
import 'package:enquiry_app/services/lock_service.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/services/auth_service.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/theme/theme_provider.dart';
import 'package:enquiry_app/providers/security_auth_provider.dart';
import 'package:enquiry_app/providers/grid_card_provider.dart';
import 'package:enquiry_app/providers/security_settings_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  throw UnimplementedError('secureStorageServiceProvider must be overridden in ProviderScope');
});

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final lockRepositoryProvider = Provider<LockRepository>((ref) {
  return LockRepository(
    apiService: ref.watch(apiServiceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

final lockServiceProvider = Provider<LockService>((ref) {
  return LockService(repo: ref.watch(lockRepositoryProvider));
});

final securityManagerProvider = ChangeNotifierProvider<SecurityManager>((ref) {
  return SecurityManager(
    repository: ref.watch(lockRepositoryProvider),
    lockService: ref.watch(lockServiceProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(storageServiceProvider));
});

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final themeProvider = ChangeNotifierProvider<ThemeProvider>((ref) {
  return ThemeProvider(ref.watch(storageServiceProvider));
});

final securityAuthProvider = ChangeNotifierProvider<SecurityAuthProvider>((ref) {
  return SecurityAuthProvider();
});

final gridCardProvider = ChangeNotifierProvider<GridCardProvider>((ref) {
  return GridCardProvider();
});

final securitySettingsProvider = ChangeNotifierProvider<SecuritySettingsProvider>((ref) {
  return SecuritySettingsProvider()..fetchSettings();
});
