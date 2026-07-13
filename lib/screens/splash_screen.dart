import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/screens/login_screen.dart';
import 'package:enquiry_app/screens/dashboard_screen.dart';
import 'package:enquiry_app/screens/app_lock_screen.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/services/secure_storage_service.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/appcontroler/appcontroler/mobile_validation_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/custom_flow_service.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static bool hasCheckedVersion = false;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  String _statusMessage = 'INITIALIZING SECURE SERVICES';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
    _startRoutingTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startRoutingTimer() {
    Timer(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;

      final storageService = ref.read(storageServiceProvider);
      final securityManager = ref.read(securityManagerProvider);

      print("========== APP START ==========");
      print("Cleaning up old cached app IDs...");
      await CustomFlowService.cleanupOldCachedAppId();
      print("Checking authentication session...");

      if (mounted) {
        setState(() {
          _statusMessage = 'Please wait, app validation...';
        });
      }

      try {
        if (SplashScreen.hasCheckedVersion) {
          debugPrint(
            "[VersionCheck] Already checked version in this app lifetime. Skipping API calls.",
          );
        } else {
          final localDetails =
              await MobileValidationService.fetchLocalDetails();
          final currentAppId = localDetails['app_id'] ?? 'USERAPP-95386';
          debugPrint("[VersionCheck] Current App ID configured: $currentAppId");

          debugPrint(
            "[VersionCheck] Requesting Admin API: GET https://mobileadmin.srivagroups.in/api/add-version",
          );
          final adminResponse = await ApiDebugLogger.httpClient
              .get(
                Uri.parse("https://mobileadmin.srivagroups.in/api/add-version"),
              )
              .timeout(const Duration(seconds: 15));

          debugPrint(
            "[VersionCheck] Admin API response status: ${adminResponse.statusCode}",
          );

          if (adminResponse.statusCode == 200) {
            final responseBody = jsonDecode(adminResponse.body);
            if (responseBody is Map && responseBody['success'] == true) {
              final dataList = responseBody['data'];
              if (dataList is List) {
                debugPrint(
                  "[VersionCheck] Found ${dataList.length} items in Admin API records.",
                );
                Map<String, dynamic>? matchedApp;
                final currentPlatform = Platform.isAndroid
                    ? 'android'
                    : (Platform.isIOS ? 'ios' : '');
                for (var item in dataList) {
                  if (item is Map<String, dynamic>) {
                    final itemAppId = (item['app_id'] ?? item['appId'])
                        ?.toString()
                        .toLowerCase();
                    final itemPlatform = item['platform']
                        ?.toString()
                        .toLowerCase();
                    final itemStatus = item['status']?.toString().toLowerCase();

                    if (itemAppId == currentAppId.toLowerCase() &&
                        (itemPlatform == null ||
                            itemPlatform.isEmpty ||
                            itemPlatform == currentPlatform) &&
                        (itemStatus == null || itemStatus == 'active')) {
                      matchedApp = item;
                      break;
                    }
                  }
                }

                if (matchedApp != null) {
                  final apiAppId =
                      (matchedApp['app_id'] ??
                              matchedApp['appId'] ??
                              currentAppId)
                          .toString();
                  final apiVersion = (matchedApp['version'] ?? '1.0.0')
                      .toString();
                  final apiSoftwareVersion =
                      (matchedApp['software_version'] ??
                              matchedApp['softwareVersion'] ??
                              '1.4.1')
                          .toString();

                  debugPrint(
                    "[VersionCheck] Found match in Admin API. Sending check to backend...",
                  );
                  debugPrint(
                    "[VersionCheck] Base URL is: https://mobilecheck.srivagroups.in/api",
                  );
                  debugPrint(
                    "[VersionCheck] Request payload: app_id: $apiAppId, version: $apiVersion, software_version: $apiSoftwareVersion",
                  );

                  final checkResponse = await ApiService().request(
                    path: '/version/check',
                    method: 'POST',
                    customBaseUrl: 'https://mobilecheck.srivagroups.in/api',
                    body: {
                      'app_id': apiAppId,
                      'version': apiVersion,
                      'software_version': apiSoftwareVersion,
                    },
                  );

                  debugPrint("[VersionCheck] Backend response: $checkResponse");

                  if (checkResponse is Map) {
                    final versionStatus = checkResponse['version_status'];
                    final statusStr = versionStatus?.toString();
                    debugPrint(
                      "[VersionCheck] Parsed version_status: $statusStr",
                    );
                    if (statusStr == '0') {
                      debugPrint(
                        "[VersionCheck] Version Status is 0. Showing non-dismissible update alert.",
                      );
                      if (mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext dialogContext) {
                            return PopScope(
                              canPop: false,
                              child: AlertDialog(
                                title: const Text(
                                  'Application Update Required',
                                ),
                                content: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'A new version of this application is available.\n',
                                    ),
                                    Text(
                                      'Please contact your administrator to install the latest version.\n',
                                    ),
                                    Text(
                                      'After installing the latest version, please log in again.',
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      await storageService.clearAuthSession();
                                      await storageService.setAuthToken('');
                                      await storageService.setUserId('');
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.remove('stored_cookies');
                                      final secureStorage =
                                          await SecureStorageService.getInstance();
                                      await secureStorage.clearAllSecure();

                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      if (mounted) {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                      return;
                    } else {
                      debugPrint(
                        "[VersionCheck] Version Status is not 0 (status: $statusStr). Proceeding to Login...",
                      );
                    }
                  }
                } else {
                  debugPrint(
                    "[VersionCheck] WARNING: No matching app config found in Admin API for App ID: $currentAppId on platform: $currentPlatform",
                  );
                }
              }
            }
          }
          SplashScreen.hasCheckedVersion = true;
        }
      } catch (e, stack) {
        debugPrint(
          "[VersionCheck] ERROR/TIMEOUT occurred during version check: $e",
        );
        debugPrint("[VersionCheck] Stacktrace: $stack");
      }

      if (storageService.isLoggedIn) {
        final int userIdInt = int.tryParse(storageService.userId) ?? 12;
        await securityManager.initializeSecurity(userIdInt).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
              "SecurityManager: Security initialization timed out, proceeding with local cache.",
            );
          },
        );
      } else {
        await storageService.clearAuthSession();
        await storageService.setAuthToken('');
        await storageService.setUserId('');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('stored_cookies');
        final secureStorage = await SecureStorageService.getInstance();
        await secureStorage.clearAllSecure();
      }

      if (!mounted) return;
      Widget nextScreen;
      if (storageService.isLoggedIn) {
        if (securityManager.isAnyLockEnabled()) {
          nextScreen = const AppLockScreen(
            isStartupBlocker: true,
            isRootReplacement: true,
          );
        } else {
          nextScreen = const DashboardScreen();
        }
      } else {
        nextScreen = const LoginScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.lightBackgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: -100.h,
                  right: -100.w,
                  child: Container(
                    width: 300.w,
                    height: 300.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150.h,
                  left: -150.w,
                  child: Container(
                    width: 400.w,
                    height: 400.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withOpacity(0.08),
                    ),
                  ),
                ),

                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(28.r),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: AppTheme.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Icon(
                            Icons.hub_rounded,
                            size: 80.r,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      SizedBox(height: 28.h),

                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: AppTheme.primaryGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          AppConstants.appName,
                          style: GoogleFonts.outfit(
                            fontSize: 38.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),

                      Text(
                        AppConstants.appSubtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 40.h,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140.w,
                        child: LinearProgressIndicator(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        _statusMessage.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
