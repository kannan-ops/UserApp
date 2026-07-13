import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/chartfile/chat_screen.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/services/auth_service.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/services/security_service.dart';
import 'package:enquiry_app/screens/security_tab_auth_screen.dart';
import 'package:enquiry_app/providers/security_settings_provider.dart';
import 'package:enquiry_app/screens/mfa_verification_screen.dart';
import 'package:enquiry_app/models/security_setting.dart';
import 'package:enquiry_app/services/google_auth_service.dart';
import 'package:enquiry_app/services/otp_service.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:dio/dio.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:enquiry_app/appcontroler/appcontroler/device_service.dart';
import 'package:enquiry_app/services/custom_flow_service.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectModule;
  final int? redirectReferenceId;
  final String? redirectUserName;
  final String? redirectInitialMessage;

  const LoginScreen({
    super.key,
    this.redirectModule,
    this.redirectReferenceId,
    this.redirectUserName,
    this.redirectInitialMessage,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLoggingIn = false;
  bool _hasRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    _emailController.addListener(() {
      print("[KEYSTROKE LOG - Email]: ${_emailController.text}");
    });
    _passwordController.addListener(() {
      print("[KEYSTROKE LOG - Password]: ${_passwordController.text}");
    });
  }

  Future<void> _checkRegistrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasRegistered = prefs.getBool('has_registered') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _storeDeviceAndAppDetails() async {
    CustomFlowService.updateRequired = false;
    final storageService = ref.read(storageServiceProvider);
    String userId = storageService.userId;

    final String deviceId = await DeviceService.getDeviceId();

    final deviceInfo = DeviceInfoPlugin();
    String deviceModel = "Unknown Model";
    String deviceBrand = "Unknown Brand";
    String androidVersion = "Unknown Android Version";
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        deviceBrand = androidInfo.brand;
        androidVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        deviceBrand = "Apple";
        androidVersion = iosInfo.systemVersion;
      }
    } catch (e) {
      print("Error getting device info on login: $e");
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final String version = packageInfo.version;
    const String softwareVersion = '1.4.1';

    print("========== REAL DEVICE INFO ==========");
    print("REAL DEVICE ID: $deviceId");
    print("REAL DEVICE MODEL: $deviceModel");
    print("REAL DEVICE BRAND: $deviceBrand");
    print("REAL ANDROID VERSION: $androidVersion");

    print("APP VERSION: ${packageInfo.version}");
    print("SOFTWARE VERSION: $softwareVersion");
    print("PACKAGE NAME: ${packageInfo.packageName}");

    print("========== LOGIN SUCCESS ==========");
    print("USER ID: $userId");
    print("DEVICE ID: $deviceId");
    print("APP VERSION: $version");
    print("SOFTWARE VERSION: $softwareVersion");
    print("Saving session securely...");

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('synced_session_$userId');
    await prefs.setBool('has_registered', true);
    if (mounted) {
      setState(() {
        _hasRegistered = true;
      });
    }

    print("DEBUG: [LoginScreen] Starting custom flow sync API call...");
    _showLoadingIndicatorDialog("Please wait, app validation...");
    bool customCheckOk = false;
    try {
      final String token = storageService.authToken;
      customCheckOk = await CustomFlowService.checkLoginAppToken(userId, token);
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!customCheckOk) {
      CustomFlowService.redirectToUpdateScreen();
      return;
    }
    print("DEBUG: [LoginScreen] Custom flow check passed.");

    print("[DEBUG] Login Success");

    final Position? position = await _requireLocationCoordinates();
    if (position == null) {
      print("Failed to obtain location coordinates. Aborting login flow.");
      return;
    }

    final String latitude = position.latitude.toString();
    final String longitude = position.longitude.toString();
    print("[DEBUG] Latitude: $latitude");
    print("[DEBUG] Longitude: $longitude");

    final String locationName = await _reverseGeocode(
      position.latitude,
      position.longitude,
    );
    print("[DEBUG] Location Name: $locationName");
    await prefs.setString('user_location_name', locationName);

    String email = _emailController.text.trim();
    if (email.isEmpty) {
      email = storageService.userEmail;
    }

    String appName = "";
    final String? lastResponse = prefs.getString(
      'last_mobile_validation_response',
    );
    if (lastResponse != null && lastResponse.isNotEmpty) {
      try {
        final decoded = jsonDecode(lastResponse);
        if (decoded is List) {
          for (var item in decoded) {
            if (item is Map) {
              final String uId =
                  item['userid']?.toString() ??
                  item['userId']?.toString() ??
                  '';
              if (uId == userId) {
                appName =
                    item['app_name']?.toString() ??
                    item['appName']?.toString() ??
                    '';
                break;
              }
            }
          }
        } else if (decoded is Map) {
          final data = decoded['data'];
          if (data is List) {
            for (var item in data) {
              if (item is Map) {
                final String uId =
                    item['userid']?.toString() ??
                    item['userId']?.toString() ??
                    '';
                if (uId == userId) {
                  appName =
                      item['app_name']?.toString() ??
                      item['appName']?.toString() ??
                      '';
                  break;
                }
              }
            }
          } else {
            final String uId =
                decoded['userid']?.toString() ??
                decoded['userId']?.toString() ??
                '';
            if (uId == userId) {
              appName =
                  decoded['app_name']?.toString() ??
                  decoded['appName']?.toString() ??
                  '';
            } else {
              appName =
                  decoded['app_name']?.toString() ??
                  decoded['appName']?.toString() ??
                  '';
            }
          }
        }
      } catch (e) {
        print("Error parsing app_name: $e");
      }
    }
    if (appName.isEmpty) {
      appName = packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : 'User App';
    }

    print("[DEBUG] Calling User Login Tracking API");

    final String trackingUrlStr =
        "https://mobileadmin.srivagroups.in/api/userlogin/received";
    final Uri trackingUrl = Uri.parse(trackingUrlStr);
    final Map<String, String> trackingHeaders = {
      "Content-Type": "application/json",
    };
    final Map<String, dynamic> trackingBody = {
      "app_id": "USERAPP-95386",
      "userid": userId,
      "username_or_email": email,
      "ime_number": deviceId,
      "latitude": latitude,
      "longitude": longitude,
      "app_name": appName,
    };

    final String trackingTimestamp = DateTime.now().toString();
    print("=============== USER LOGIN TRACKING REQUEST ===============");
    print("URL      : $trackingUrlStr");
    print("METHOD   : POST");
    print("HEADERS  : $trackingHeaders");
    print("BODY     : ${jsonEncode(trackingBody)}");
    print("TIME     : $trackingTimestamp");
    print("======================");

    final trackingStartTime = DateTime.now();
    final trackingClient = ApiDebugLogger.wrapClient(http.Client());
    try {
      print("Sending app_id: USERAPP-95386");
      final trackingResponse = await trackingClient
          .post(
            trackingUrl,
            headers: trackingHeaders,
            body: jsonEncode(trackingBody),
          )
          .timeout(const Duration(seconds: 15));

      final trackingDuration = DateTime.now().difference(trackingStartTime);

      print("=============== USER LOGIN TRACKING RESPONSE ==============");
      print("STATUS   : ${trackingResponse.statusCode}");
      print("BODY     : ${trackingResponse.body}");
      print("DURATION : ${trackingDuration.inMilliseconds} ms");
      print("=====================");

      if (trackingResponse.statusCode == 200 ||
          trackingResponse.statusCode == 201) {
        print("[DEBUG] Tracking API Success");
      } else {
        print("[DEBUG] Tracking API Failed");
        print("=============== USER LOGIN TRACKING ERROR =================");
        print("STATUS   : ${trackingResponse.statusCode}");
        print("MESSAGE  : Server Error");
        print("BODY     : ${trackingResponse.body}");
        print("STACKTRACE : ");
        print("=========================");
      }
    } catch (e, stack) {
      print("[DEBUG] Tracking API Failed");
      print("=============== USER LOGIN TRACKING ERROR =================");
      print("STATUS   : 500");
      print("MESSAGE  : $e");
      print("BODY     : null");
      print("STACKTRACE : $stack");
      print("=========================");
    } finally {
      trackingClient.close();
    }

    print("[DEBUG] Navigation Continues");

    print("Session stored successfully");
    print("Navigating to Dashboard");
  }

  Future<Position?> _requireLocationCoordinates() async {
    while (mounted) {
      print('Before checkPermission');
      var status = await Permission.location.status;
      print('Current Permission: $status');

      if (status.isDenied) {
        print('Before requestPermission');
        final newStatus = await Permission.location.request();
        print('After requestPermission: $newStatus');
        status = newStatus;
      }

      if (status.isPermanentlyDenied) {
        print("[DEBUG] Location Permission Denied");

        openAppSettings();
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text("Permission Required"),
                content: const Text(
                  "Location permission is permanently denied. We have opened App Settings. Please enable the location permission in settings to continue.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text("Retry"),
                  ),
                ],
              );
            },
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      if (status.isDenied) {
        print("[DEBUG] Location Permission Denied");
        bool retry = false;
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text("Permission Required"),
                content: const Text(
                  "Location permission is required to continue.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      retry = false;
                      Navigator.of(dialogContext).pop();
                      openAppSettings();
                    },
                    child: const Text("Open Settings"),
                  ),
                  TextButton(
                    onPressed: () {
                      retry = true;
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text("Retry"),
                  ),
                ],
              );
            },
          );
        }
        if (!retry) {
          await Future.delayed(const Duration(seconds: 2));
        }
        continue;
      }

      if (status.isGranted || status.isLimited) {
        print("[DEBUG] Location Permission Granted");

        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        print("[DEBUG] Location Service Enabled: $serviceEnabled");

        if (!serviceEnabled) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text("Location Service Disabled"),
                  content: const Text(
                    "Please enable location services on your device to continue.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                );
              },
            );
          }
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        print("[DEBUG] Fetching GPS Coordinates");
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(const Duration(seconds: 10));
          return position;
        } catch (e, stack) {
          print("[DEBUG] Failed To Fetch Coordinates");
          print("Exception: $e");
          print("Stacktrace: $stack");
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text("Location Error"),
                  content: Text(
                    "Failed to fetch GPS coordinates: $e. Make sure location services are enabled.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                );
              },
            );
          }
        }
      }
    }
    return null;
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    final client = ApiDebugLogger.wrapClient(http.Client());
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1",
      );
      final response = await client
          .get(
            url,
            headers: {
              "User-Agent": "lockscreen_app/1.0",
              "Accept-Language": "en",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final address = decoded['address'];
          if (address is Map) {
            final city =
                address['city'] ??
                address['town'] ??
                address['village'] ??
                address['suburb'] ??
                address['county'] ??
                '';
            final state = address['state'] ?? '';
            final country = address['country'] ?? '';

            final List<String> parts = [];
            if (city.toString().isNotEmpty) parts.add(city.toString());
            if (state.toString().isNotEmpty) parts.add(state.toString());
            if (country.toString().isNotEmpty) parts.add(country.toString());

            if (parts.isNotEmpty) {
              return parts.join(", ");
            }
          }
          final displayName = decoded['display_name'];
          if (displayName != null) {
            return displayName.toString();
          }
        }
      }
    } catch (e) {
      print("Reverse geocoding error: $e");
    } finally {
      client.close();
    }
    return "Coimbatore, Tamil Nadu, India";
  }

  void _handleLogin() async {
    if (_isLoggingIn) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isLoggingIn = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      SecurityService.resetSessionHistoryState();

      final success = await authService.login(email, password);

      if (!mounted) return;

      if (success) {
        final storageService = ref.read(storageServiceProvider);
        final int userIdInt = int.tryParse(storageService.userId) ?? 12;

        SecurityService(
          ApiService(),
        ).saveLoginHistory(userId: userIdInt, method: 'pincode').catchError((
          err,
        ) {
          print(
            'DEBUG [LoginScreen]: Failed saving login history on backend: $err',
          );
          return <String, dynamic>{};
        });

        final settingsProvider = ref.read(securitySettingsProvider);
        await settingsProvider.fetchSettings(userId: userIdInt);

        final isSmsEnabled = settingsProvider.settings
            .firstWhere(
              (s) => s.key == 'sms_otp',
              orElse: () => SecuritySetting(
                key: 'sms_otp',
                title: '',
                subtitle: '',
                icon: Icons.sms,
                isEnabled: false,
              ),
            )
            .isEnabled;

        final isWhatsappEnabled = settingsProvider.settings
            .firstWhere(
              (s) => s.key == 'whatsapp_otp',
              orElse: () => SecuritySetting(
                key: 'whatsapp_otp',
                title: '',
                subtitle: '',
                icon: Icons.chat,
                isEnabled: false,
              ),
            )
            .isEnabled;

        final isEmailEnabled = settingsProvider.settings
            .firstWhere(
              (s) => s.key == 'mail_otp',
              orElse: () => SecuritySetting(
                key: 'mail_otp',
                title: '',
                subtitle: '',
                icon: Icons.email,
                isEnabled: false,
              ),
            )
            .isEnabled;

        if (isSmsEnabled || isWhatsappEnabled || isEmailEnabled) {
          final bool verified =
              await navigator.push(
                MaterialPageRoute(
                  builder: (context) => const MfaVerificationScreen(
                    actionDescription: 'authenticate and open your dashboard',
                  ),
                ),
              ) ??
              false;

          if (!verified) {
            _showErrorSnackBar(
              'MFA Required',
              'Multi-Factor OTP verification failed or cancelled.',
            );
            return;
          }
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12.w),
                const Text('Identity Verified successfully!'),
              ],
            ),
            backgroundColor: AppConstants.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        await _storeDeviceAndAppDetails();

        final securityManager = ref.read(securityManagerProvider);
        await securityManager.initializeSecurity(userIdInt).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
              "SecurityManager: Security initialization timed out during login.",
            );
          },
        );

        if (widget.redirectModule != null && widget.redirectReferenceId != null) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardScreen(),
            ),
          );
          navigator.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                module: widget.redirectModule!,
                referenceId: widget.redirectReferenceId!,
                userName: widget.redirectUserName ?? "Client",
                initialMessage: widget.redirectInitialMessage,
              ),
            ),
          );
        } else {
          navigator.pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  DashboardScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showErrorSnackBar(
          'Access Denied',
          'Invalid credentials. Check Email & Password.',
        );
      }
    } on NewDeviceDetectedException {
      if (!mounted) return;
      _showErrorSnackBar(
        'Verification Required',
        'New device detected. Redirecting to verification page...',
      );
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SecurityTabAuthScreen(),
            ),
            (route) => false,
          );
        }
      });
    } on InvalidCredentialsException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Access Denied', e.message);
    } on NoInternetException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Connection Failure', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        'Verification Error',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoggingIn = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _launchRegisterUrl() async {
    final Uri url = Uri.parse('https://user.jobes24x7.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Error', 'Could not launch registration link.');
    }
  }

  void _autofillCredentials() {
    setState(() {
      _emailController.text = 'admin@gmail.com';
      _passwordController.text = '123456';
    });
  }

  void _showLoadingIndicatorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 20.h),
              Text(
                message,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showGoogleAccountPicker() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          titlePadding: EdgeInsets.all(24.r),
          contentPadding: EdgeInsets.symmetric(horizontal: 24.r),
          actionsPadding: EdgeInsets.all(16.r),
          title: Row(
            children: [
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                width: 24.w,
                height: 24.w,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_circle),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Google Account',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Enter your Gmail address to continue',
                      style: GoogleFonts.outfit(
                        fontSize: 12.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.1),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        labelText: 'Gmail Address',
                        hintText: 'yourname@gmail.com',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ),
                  Divider(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.1),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(emailController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showOtpVerificationDialog(String email) async {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final otpService = OtpService();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(
              color: AppConstants.accentColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          titlePadding: EdgeInsets.all(24.r),
          contentPadding: EdgeInsets.symmetric(horizontal: 24.r),
          actionsPadding: EdgeInsets.all(16.r),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppConstants.accentColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'OTP Verification',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.sp,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'We\'ve sent a 6-digit OTP code to your Gmail:',
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    email,
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8.0,
                    ),
                    decoration: InputDecoration(
                      labelText: '6-Digit OTP Code',
                      hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢',
                      alignLabelWithHint: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'OTP code is required';
                      }
                      if (value.trim().length != 6) {
                        return 'Enter a 6-digit code';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final verified = otpService.verifyOtp(
                    email,
                    otpController.text.trim(),
                  );
                  Navigator.of(context).pop(verified);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Verify OTP',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<String?> _showPasswordDialog(
    String email, {
    bool isNewUser = false,
  }) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePasswordText = true;
    bool obscureConfirmPasswordText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              titlePadding: EdgeInsets.all(24.r),
              contentPadding: EdgeInsets.symmetric(horizontal: 24.r),
              actionsPadding: EdgeInsets.all(16.r),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isNewUser ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      isNewUser ? 'Create Password' : 'Account Password',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isNewUser
                            ? 'Create a secure password for your new account:'
                            : 'Provide password for security authentication:',
                        style: GoogleFonts.outfit(
                          fontSize: 13.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        email,
                        style: GoogleFonts.outfit(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePasswordText,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePasswordText
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                obscurePasswordText = !obscurePasswordText;
                              });
                            },
                          ),
                          labelText: isNewUser ? 'New Password' : 'Password',
                          hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password is required';
                          }
                          if (value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (isNewUser) ...[
                        SizedBox(height: 16.h),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPasswordText,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.key_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPasswordText
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setStateDialog(() {
                                  obscureConfirmPasswordText =
                                      !obscureConfirmPasswordText;
                                });
                              },
                            ),
                            labelText: 'Confirm Password',
                            hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value.trim() !=
                                passwordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(passwordController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    isNewUser ? 'Create' : 'Authenticate',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleGoogleSignIn() async {
    if (_isLoggingIn) return;
    print(
      "DEBUG [LoginScreen]: Continue with Google clicked. Triggering native Google Sign-In...",
    );
    setState(() {
      _isLoading = true;
      _isLoggingIn = true;
    });

    final googleAuthService = GoogleAuthService();

    try {
      final googleUser = await googleAuthService.signInWithGoogle();
      if (googleUser != null) {
        print(
          "DEBUG [LoginScreen]: Google Sign-In response received. email: ${googleUser.email}, displayName: ${googleUser.displayName}",
        );
        final selectedEmail = googleUser.email;
        await _processGoogleAuthWithEmail(selectedEmail);
      } else {
        print(
          "DEBUG [LoginScreen]: Google Sign-In response is null (User cancelled or native sign-in failed).",
        );
        _showErrorSnackBar(
          'Google Sign-In',
          'No Google account selected or sign-in failed.',
        );
      }
    } catch (e) {
      print("DEBUG [LoginScreen]: Exception during Google Sign-In: $e");

      final errorStr = e.toString();
      if (errorStr.contains('10') || errorStr.contains('ApiException: 10')) {
        print(
          "DEBUG [LoginScreen]: ApiException 10 detected (Configuration issue). Falling back to manual Gmail login...",
        );
        _showErrorSnackBar(
          'Google Configuration Error',
          'Google Sign-In is not configured correctly (SHA-1 mismatch). Falling back to manual entry...',
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _handleManualGmailSignIn();
          }
        });
      } else {
        _showErrorSnackBar(
          'Verification Error',
          errorStr.replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoggingIn = false;
        });
      }
    }
  }

  void _handleManualGmailSignIn() async {
    if (_isLoggingIn) return;
    print(
      "DEBUG [LoginScreen]: Add another account clicked. Showing manual email dialog picker...",
    );
    setState(() {
      _isLoading = true;
      _isLoggingIn = true;
    });

    try {
      final selectedEmail = await _showGoogleAccountPicker();
      print(
        "DEBUG [LoginScreen]: Manual email dialog response: $selectedEmail",
      );
      if (selectedEmail != null && selectedEmail.isNotEmpty) {
        await _processGoogleAuthWithEmail(selectedEmail);
      } else {
        print(
          "DEBUG [LoginScreen]: Manual email entry was cancelled or empty.",
        );
      }
    } catch (e) {
      print("DEBUG [LoginScreen]: Exception in Manual Gmail Sign-In flow: $e");
      _showErrorSnackBar(
        'Verification Error',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoggingIn = false;
        });
      }
    }
  }

  Future<void> _processGoogleAuthWithEmail(String selectedEmail) async {
    print(
      "DEBUG [LoginScreen]: Processing authentication for email: $selectedEmail",
    );
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final otpService = OtpService();

    try {
      if (!mounted) return;
      _showLoadingIndicatorDialog('Sending verification code...');
      print("DEBUG [LoginScreen]: Dispatching OTP code via OtpService...");
      final otpSent = await otpService.sendOtp(selectedEmail);
      if (!mounted) return;
      Navigator.of(context).pop();

      print("DEBUG [LoginScreen]: OTP send result status: $otpSent");
      if (!otpSent) {
        _showErrorSnackBar(
          'OTP Send Failure',
          'Failed to dispatch verification code via SMTP.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print("DEBUG [LoginScreen]: Showing OTP verification dialog...");
      final otpVerified = await _showOtpVerificationDialog(selectedEmail);
      print(
        "DEBUG [LoginScreen]: OTP verification dialog result: $otpVerified",
      );
      if (!otpVerified) {
        _showErrorSnackBar(
          'OTP Verification Failed',
          'Verification code is invalid or cancelled.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final authService = ref.read(authServiceProvider);

      if (!mounted) return;
      _showLoadingIndicatorDialog('Checking account status...');
      print(
        "DEBUG [LoginScreen]: Checking user existence status for $selectedEmail...",
      );
      bool userExists = false;
      try {
        userExists = await authService.checkUserExists(selectedEmail);
      } catch (e) {
        print("DEBUG [LoginScreen]: Exception checking user existence: $e");
        if (mounted) Navigator.of(context).pop();
        _showErrorSnackBar(
          'Existence Check Failed',
          'Could not verify user existence: $e',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      if (mounted) Navigator.of(context).pop();
      print("DEBUG [LoginScreen]: User exists check result: $userExists");

      String? password;
      if (userExists) {
        print(
          "DEBUG [LoginScreen]: User exists. Showing login password prompt dialog...",
        );
        password = await _showPasswordDialog(selectedEmail, isNewUser: false);
        print(
          "DEBUG [LoginScreen]: Password prompt response received (is empty/null: ${password == null || password.isEmpty})",
        );
        if (password == null || password.isEmpty) {
          _showErrorSnackBar(
            'Authentication Cancelled',
            'Password is required to authenticate.',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else {
        print(
          "DEBUG [LoginScreen]: User does not exist. Showing create password prompt dialog...",
        );
        password = await _showPasswordDialog(selectedEmail, isNewUser: true);
        print(
          "DEBUG [LoginScreen]: Create password prompt response received (is empty/null: ${password == null || password.isEmpty})",
        );
        if (password == null || password.isEmpty) {
          _showErrorSnackBar(
            'Registration Cancelled',
            'Password is required to register.',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        if (!mounted) return;
        _showLoadingIndicatorDialog('Creating your account...');
        print(
          "DEBUG [LoginScreen]: Sending registration request to backend for $selectedEmail...",
        );
        bool registrationSuccess = false;
        try {
          registrationSuccess = await authService.registerUser(
            selectedEmail,
            password,
          );
        } catch (e) {
          print(
            "DEBUG [LoginScreen]: Exception during registration request: $e",
          );
          if (mounted) Navigator.of(context).pop();
          String errorMsg = e.toString();
          if (e is DioException) {
            final responseData = e.response?.data;
            if (responseData != null &&
                responseData['data'] != null &&
                responseData['data']['message'] != null) {
              errorMsg = responseData['data']['message'].toString();
            }
          }
          _showErrorSnackBar('Registration Failed', errorMsg);
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (mounted) Navigator.of(context).pop();
        print(
          "DEBUG [LoginScreen]: Registration result status: $registrationSuccess",
        );

        if (!registrationSuccess) {
          _showErrorSnackBar(
            'Registration Failed',
            'Failed to create user account. Please try again.',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      print(
        "DEBUG [LoginScreen]: Dispatching login request to backend for $selectedEmail...",
      );
      final success = await authService.login(selectedEmail, password);
      print("DEBUG [LoginScreen]: Login request result status: $success");

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (success) {
        print("DEBUG [LoginScreen]: Login success. Saving login history...");
        SecurityService(
          ApiService(),
        ).saveLoginHistory(userId: 1, method: 'google').catchError((err) {
          print(
            'DEBUG [LoginScreen]: Failed saving login history on backend: $err',
          );
          return <String, dynamic>{};
        });

        print(
          "DEBUG [LoginScreen]: Fetching security settings to check MFA status...",
        );
        final settingsProvider = ref.read(securitySettingsProvider);
        await settingsProvider.fetchSettings();

        final isSmsEnabled = settingsProvider.settings
            .firstWhere(
              (s) => s.key == 'sms_otp',
              orElse: () => SecuritySetting(
                key: 'sms_otp',
                title: '',
                subtitle: '',
                icon: Icons.sms,
                isEnabled: false,
              ),
            )
            .isEnabled;

        final isWhatsappEnabled = settingsProvider.settings
            .firstWhere(
              (s) => s.key == 'whatsapp_otp',
              orElse: () => SecuritySetting(
                key: 'whatsapp_otp',
                title: '',
                subtitle: '',
                icon: Icons.chat,
                isEnabled: false,
              ),
            )
            .isEnabled;

        final isEmailEnabled = settingsProvider.settings
            .firstWhere(
              (s) => s.key == 'mail_otp',
              orElse: () => SecuritySetting(
                key: 'mail_otp',
                title: '',
                subtitle: '',
                icon: Icons.email,
                isEnabled: false,
              ),
            )
            .isEnabled;
        print(
          "DEBUG [LoginScreen]: MFA Config: SMS=$isSmsEnabled, Whatsapp=$isWhatsappEnabled, Email=$isEmailEnabled",
        );

        if (isSmsEnabled || isWhatsappEnabled || isEmailEnabled) {
          print(
            "DEBUG [LoginScreen]: MFA check required. Redirecting to MFA screen...",
          );
          final bool verified =
              await navigator.push(
                MaterialPageRoute(
                  builder: (context) => const MfaVerificationScreen(
                    actionDescription: 'authenticate and open your dashboard',
                  ),
                ),
              ) ??
              false;
          print(
            "DEBUG [LoginScreen]: MFA verification result status: $verified",
          );

          if (!verified) {
            _showErrorSnackBar(
              'MFA Required',
              'Multi-Factor OTP verification failed or cancelled.',
            );
            return;
          }
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12.w),
                const Text('Google Identity Verified successfully!'),
              ],
            ),
            backgroundColor: AppConstants.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        print("DEBUG [LoginScreen]: Storing device and app details...");
        await _storeDeviceAndAppDetails();

        print("DEBUG [LoginScreen]: Transitioning to DashboardScreen...");
        navigator.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        print(
          "DEBUG [LoginScreen]: Access Denied. Invalid Google credentials.",
        );
        _showErrorSnackBar(
          'Access Denied',
          'Invalid Google credentials. Check Email & Password.',
        );
      }
    } on NewDeviceDetectedException catch (e) {
      print("DEBUG [LoginScreen]: NewDeviceDetectedException caught: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(
        'Verification Required',
        'New device detected. Redirecting to verification page...',
      );
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SecurityTabAuthScreen(),
            ),
            (route) => false,
          );
        }
      });
    } on InvalidCredentialsException catch (e) {
      print("DEBUG [LoginScreen]: InvalidCredentialsException caught: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Access Denied', e.message);
    } on NoInternetException catch (e) {
      print("DEBUG [LoginScreen]: NoInternetException caught: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Connection Failure', e.message);
    } catch (e) {
      print(
        "DEBUG [LoginScreen]: Exception caught during authentication process: $e",
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(
        'Verification Error',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 30.h),

                  Center(
                    child: Container(
                      padding: EdgeInsets.all(18.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ).createShader(bounds),
                        child: Icon(
                          Icons.lock_open_rounded,
                          size: 48.r,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'Welcome Back',
                    style: GoogleFonts.outfit(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: Alignment.center.x == 0
                        ? TextAlign.center
                        : TextAlign.left,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Provide security authorization to unlock dashboard',
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: Alignment.center.x == 0
                        ? TextAlign.center
                        : TextAlign.left,
                  ),

                  SizedBox(height: 36.h),

                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'VERIFY IDENTITY',
                              style: GoogleFonts.outfit(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 20.h),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.alternate_email_rounded,
                                  size: 20.w,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.7),
                                ),
                                labelText: 'Email Address',
                                hintText: 'admin@gmail.com',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: 20.h),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.key_rounded,
                                  size: 20.w,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.7),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20.w,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                labelText: 'Password',
                                hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: 32.h),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24.w,
                                      height: 24.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Authenticate',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18.w,
                                        ),
                                      ],
                                    ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.1),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                                    width: 20.w,
                                    height: 20.w,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.account_circle,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'Continue with Google',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleManualGmailSignIn,
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 18.w,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Add another account',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                              height: 24.h,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "New User? ",
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.sp,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _launchRegisterUrl,
                                  child: Text(
                                    "Register here",
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  GestureDetector(
                    onTap: _autofillCredentials,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0.4)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20.w,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Developer Shortcut Available',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Tap here to autofill test credentials.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.sp,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
