import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/services/auth_service.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/theme/theme_provider.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/screens/splash_screen.dart';
import 'package:enquiry_app/screens/login_screen.dart';

import 'package:enquiry_app/providers/riverpod_providers.dart';

import 'package:enquiry_app/services/secure_storage_service.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/repositories/lock_repository.dart';
import 'package:enquiry_app/services/lock_service.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/appcontroler/appcontroler/mobile_validation_service.dart';
import 'package:enquiry_app/services/custom_flow_service.dart';

void main() async {
  runZoned(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    final storageService = await StorageService.getInstance();
    final secureStorage = await SecureStorageService.getInstance();
    final apiService = ApiService();
    final lockRepository = LockRepository(
      apiService: apiService,
      secureStorage: secureStorage,
    );
    final lockService = LockService(repo: lockRepository);
    final securityManager = SecurityManager(
      repository: lockRepository,
      lockService: lockService,
    );

    MobileValidationService.syncUserAppData();

    runApp(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
          lockRepositoryProvider.overrideWithValue(lockRepository),
          lockServiceProvider.overrideWithValue(lockService),
          securityManagerProvider.overrideWith((ref) => securityManager),
        ],
        child: const CircuitPointApp(),
      ),
    );
  }, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      if (kDebugMode) {
        parent.print(zone, line);
      }
    },
  ));
}

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void navigateToLogin() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}

class CircuitPointApp extends ConsumerStatefulWidget {
  const CircuitPointApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CircuitPointAppState();
}

class _CircuitPointAppState extends ConsumerState<CircuitPointApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    CustomFlowService.handleAppLifecycleChange(state);
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _handleAppResume() async {
    final storageService = ref.read(storageServiceProvider);
    if (storageService.isLoggedIn) {
      // App resumed from background - do not show lock screen (only show on cold startup)
    }

    await MobileValidationService.syncUserAppData();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final themeProviderVal = ref.watch(themeProvider);

        return MaterialApp(
          title: 'CircuitPoint',
          navigatorKey: NavigationService.navigatorKey,
          debugShowCheckedModeBanner: false,

          themeMode: themeProviderVal.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,

          home: const SplashScreen(),
        );
      },
    );
  }
}
