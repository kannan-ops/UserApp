import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/widgets/pin_pad.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/screens/login_screen.dart';
import 'package:enquiry_app/screens/dashboard_screen.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/services/security_service.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/repositories/lock_repository.dart';
import 'package:enquiry_app/services/lock_service.dart';
import 'dart:io';
import 'package:enquiry_app/services/otp_service.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  final bool isStartupBlocker;
  final bool isRootReplacement;

  const AppLockScreen({
    super.key,
    this.isStartupBlocker = false,
    this.isRootReplacement = false,
  });

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  late StorageService _storageService;
  late SecurityManager _securityManager;
  late LockRepository _lockRepository;

  String _errorMessage = '';
  bool _showBiometricOption = false;
  bool _isAuthenticating = false;
  List<String> _pendingLocks = [];

  @override
  void initState() {
    super.initState();
    _storageService = ref.read(storageServiceProvider);
    _securityManager = ref.read(securityManagerProvider);
    _lockRepository = ref.read(lockRepositoryProvider);

    final List<String> allCheckKeys = [
      'pincode',
      'pattern_lock',
      'fingerprint',
      'face_lock',
      'grid_card',
      'security_tab',
      'sms_otp',
      'whatsapp_otp',
      'mail_otp',
    ];

    _pendingLocks = allCheckKeys
        .where((key) => _securityManager.isLockEnabled(key))
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkBiometrics();
        _triggerNextVerification();
      }
    });
  }

  void _showDisabledMethodDialog(String method) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
              ),
              SizedBox(width: 12.w),
              const Text('Method Disabled'),
            ],
          ),
          content: Text(
            'Enable $method inside the active Security Settings Console first before attempting dynamic sync validations.',
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              child: Text(
                'Close',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _checkBiometrics() async {
    final biometricService = ref.read(biometricServiceProvider);

    final bool isFingerprintEnabled = _securityManager.isLockEnabled(
      'fingerprint',
    );
    final bool isFaceEnabled = _securityManager.isLockEnabled('face_lock');

    if (isFingerprintEnabled || isFaceEnabled) {
      final isHardwareAvailable = await biometricService.isHardwareSupported();
      if (isHardwareAvailable) {
        setState(() {
          _showBiometricOption = true;
        });
      }
    }
  }

  void _triggerBiometricAuth() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final isFingerprintEnabled = _securityManager.isLockEnabled(
        'fingerprint',
      );
      final isFaceEnabled = _securityManager.isLockEnabled('face_lock');

      if (!isFingerprintEnabled && !isFaceEnabled) {
        _showDisabledMethodDialog('Biometrics (Fingerprint/Face Lock)');
        return;
      }

      final biometricService = ref.read(biometricServiceProvider);
      final result = await biometricService.authenticate(
        reason: 'Verify identity to unlock CircuitPoint',
      );

      if (result.success) {
        final bool isFace = isFaceEnabled && !isFingerprintEnabled;
        SecurityService(ApiService())
            .saveLoginHistory(
              userId: 1,
              method: isFace ? 'face_lock' : 'fingerprint',
            )
            .catchError((err) {
              debugPrint(
                'DEBUG [AppLockScreen]: Failed saving biometric history: $err',
              );
              return <String, dynamic>{};
            });

        if (isFingerprintEnabled) {
          _markCurrentLockAsVerified('fingerprint');
        } else if (isFaceEnabled) {
          _markCurrentLockAsVerified('face_lock');
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result.message;
          });

          Future.delayed(const Duration(milliseconds: 3500), () {
            if (mounted) {
              setState(() {
                _errorMessage = '';
              });
            }
          });
        }
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  void _verifyLockHandler(String key) async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final lockService = ref.read(lockServiceProvider);
      final handler = lockService.getHandler(key);
      final bool success = await handler.authenticate(context, _lockRepository);
      if (success) {
        SecurityService(
          ApiService(),
        ).saveLoginHistory(userId: 1, method: key).catchError((err) {
          debugPrint('DEBUG [AppLockScreen]: Failed saving history: $err');
          return <String, dynamic>{};
        });

        _markCurrentLockAsVerified(key);
      } else {
        setState(() {
          _errorMessage = 'Verification Failed for ${_getDisplayName(key)}';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _errorMessage = '';
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Verification error: $e");
    } finally {
      _isAuthenticating = false;
    }
  }

  void _triggerNextVerification() {
    if (_pendingLocks.isEmpty) {
      if (widget.isRootReplacement) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pop(true);
      }
      return;
    }

    final nextLock = _pendingLocks.first;
    if (nextLock == 'fingerprint' || nextLock == 'face_lock') {
      Future.delayed(const Duration(milliseconds: 500), () {
        _triggerBiometricAuth();
      });
    } else if (nextLock == 'grid_card' ||
        nextLock == 'security_tab' ||
        nextLock == 'sms_otp' ||
        nextLock == 'whatsapp_otp' ||
        nextLock == 'mail_otp') {
      Future.delayed(const Duration(milliseconds: 300), () {
        _verifyLockHandler(nextLock);
      });
    }
  }

  void _markCurrentLockAsVerified(String key) {
    if (mounted) {
      setState(() {
        _pendingLocks.remove(key);
        _errorMessage = '';
      });

      if (_pendingLocks.isEmpty) {
        if (widget.isRootReplacement) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        _triggerNextVerification();
      }
    }
  }

  String _getDisplayName(String key) {
    switch (key) {
      case 'pincode':
        return 'PIN Code';
      case 'pattern_lock':
        return 'Pattern Lock';
      case 'fingerprint':
        return 'Fingerprint Identification';
      case 'face_lock':
        return 'Face ID Identification';
      case 'grid_card':
        return 'Grid Card';
      case 'security_tab':
        return 'Security Tab Math';
      case 'sms_otp':
        return 'SMS OTP';
      case 'whatsapp_otp':
        return 'WhatsApp OTP';
      case 'mail_otp':
        return 'Mail OTP';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getLockIcon(String key) {
    switch (key) {
      case 'pincode':
        return Icons.dialpad_rounded;
      case 'pattern_lock':
        return Icons.gesture_rounded;
      case 'fingerprint':
        return Icons.fingerprint_rounded;
      case 'face_lock':
        return Icons.face_retouching_natural_rounded;
      case 'grid_card':
        return Icons.grid_view_rounded;
      case 'security_tab':
        return Icons.shield_rounded;
      case 'sms_otp':
        return Icons.sms_outlined;
      case 'whatsapp_otp':
        return Icons.chat_bubble_outline_rounded;
      case 'mail_otp':
        return Icons.alternate_email_rounded;
      default:
        return Icons.lock_outline_rounded;
    }
  }

  void _onPinCompleted(String pin) async {
    final isPinEnabled = _securityManager.isLockEnabled('pincode');

    if (!isPinEnabled) {
      _showDisabledMethodDialog('PIN Code Protection');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    final bool isCorrect = await _lockRepository.verifyPin(pin);

    setState(() {
      _isAuthenticating = false;
    });

    if (isCorrect) {
      SecurityService(
        ApiService(),
      ).saveLoginHistory(userId: 1, method: 'pincode').catchError((err) {
        debugPrint('DEBUG [AppLockScreen]: Failed saving pin history: $err');
        return <String, dynamic>{};
      });

      _markCurrentLockAsVerified('pincode');
    } else {
      setState(() {
        _errorMessage = 'Incorrect Security PIN';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _errorMessage = '';
          });
        }
      });
    }
  }

  void _onPatternCompleted(List<int> pattern) {
    final isPatternEnabled = _securityManager.isLockEnabled('pattern_lock');

    if (!isPatternEnabled) {
      _showDisabledMethodDialog('Pattern Lock');
      return;
    }

    final patternString = pattern.join(',');
    final String savedPattern = _lockRepository.getLocalValue('pattern_lock');

    if (patternString == savedPattern) {
      SecurityService(
        ApiService(),
      ).saveLoginHistory(userId: 1, method: 'pattern').catchError((err) {
        debugPrint(
          'DEBUG [AppLockScreen]: Failed saving pattern history: $err',
        );
        return <String, dynamic>{};
      });

      _markCurrentLockAsVerified('pattern_lock');
    } else {
      setState(() {
        _errorMessage = 'Incorrect Security Pattern';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _errorMessage = '';
          });
        }
      });
    }
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ForgotPasswordDialog(
          storageService: _storageService,
          lockRepository: _lockRepository,
          securityManager: _securityManager,
          onSuccess: () {
            Navigator.pop(context); // pop the dialog
            setState(() {
              _pendingLocks.clear();
            });
            _triggerNextVerification(); // will see _pendingLocks is empty and route/unlock!
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userName = _storageService.userName;
    final userPhoto = _storageService.userPhoto;

    Widget lockBody;
    if (_pendingLocks.isEmpty) {
      lockBody = Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.shield_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Authentication Cleared',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      final String currentLockKey = _pendingLocks.first;
      if (currentLockKey == 'pincode') {
        lockBody = PinPad(
          onPinCompleted: _onPinCompleted,
          showBiometricButton: _showBiometricOption,
          onBiometricPressed: _triggerBiometricAuth,
          errorMessage: _errorMessage,
        );
      } else if (currentLockKey == 'pattern_lock') {
        lockBody = Column(
          children: [
            Container(
              height: 280.h,
              width: 280.w,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.01),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  width: 1.5,
                ),
              ),
              child: PatternLock(
                selectedColor: Theme.of(context).colorScheme.primary,
                dimension: 3,
                pointRadius: 8,
                showInput: true,
                onInputComplete: _onPatternCompleted,
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Text(
                _errorMessage,
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              SizedBox(height: 16.h),
              Text(
                'Draw pattern to verify your security clearance',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (_showBiometricOption) ...[
              SizedBox(height: 24.h),
              IconButton.filledTonal(
                iconSize: 32.r,
                padding: const EdgeInsets.all(16),
                icon: Icon(
                  Icons.fingerprint_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _triggerBiometricAuth,
              ),
            ],
          ],
        );
      } else {
        final lockName = _getDisplayName(currentLockKey);
        final IconData lockIcon = _getLockIcon(currentLockKey);

        lockBody = Column(
          children: [
            Icon(
              lockIcon,
              size: 64.r,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 16.h),
            Text(
              'Verification Required',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Please verify your $lockName to proceed',
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Text(
                _errorMessage,
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () => _verifyLockHandler(currentLockKey),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Start Verification',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        );
      }
    }

    return PopScope(
      canPop: !widget.isStartupBlocker,
      child: ScreenUtilInit(
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
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 20.h,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 20.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 16.w,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'CIRCUITPOINT SECURE VAULT',
                            style: GoogleFonts.outfit(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 32.h),

                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80.r,
                              height: 80.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.15),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: userPhoto.isNotEmpty
                                    ? Image.network(
                                        userPhoto,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.person),
                                      )
                                    : const Icon(Icons.person, size: 40),
                              ),
                            ),
                            SizedBox(height: 16.h),

                            Text(
                              'Authorized Access Only',
                              style: GoogleFonts.outfit(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _pendingLocks.length > 1
                                  ? 'Clearance: $userName (${_pendingLocks.length} locks pending)'
                                  : 'Clearance: $userName',
                              style: GoogleFonts.outfit(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 40.h),

                      lockBody,

                      SizedBox(height: 20.h),

                      TextButton.icon(
                        icon: Icon(
                          Icons.mail_outline_rounded,
                          size: 16.w,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          'Forgot Password / PIN?',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _handleForgotPassword,
                      ),

                      SizedBox(height: 30.h),

                      if (widget.isStartupBlocker) ...[
                        SizedBox(height: 10.h),
                        TextButton(
                          onPressed: () async {
                            await _storageService.clearAuthSession();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Log Out / Switch Account',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final StorageService storageService;
  final LockRepository lockRepository;
  final SecurityManager securityManager;
  final VoidCallback onSuccess;

  const _ForgotPasswordDialog({
    required this.storageService,
    required this.lockRepository,
    required this.securityManager,
    required this.onSuccess,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  String _step = 'email'; // 'email', 'otp', 'new_pin'
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  String _targetEmail = '';

  @override
  void initState() {
    super.initState();
    _targetEmail = widget.storageService.userEmail;
    _emailController.text = _targetEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final bool hasNet = await _checkInternet();
    if (!hasNet) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please connect to network.';
      });
      return;
    }

    final bool success = await MailOtpService.sendOtpEmail(email);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _targetEmail = email;
        widget.storageService.setUserEmail(email); // update cache
        _step = 'otp';
      });
    } else {
      setState(() {
        _errorMessage = 'Failed to send OTP email. Please try again.';
      });
    }
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit OTP code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final bool isValid = MailOtpService.validateMailOtp(_targetEmail, otp);

    setState(() {
      _isLoading = false;
    });

    if (isValid) {
      setState(() {
        _step = 'new_pin';
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid or expired OTP. Please try again.';
      });
    }
  }

  void _savePin() async {
    final newPin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      setState(() {
        _errorMessage = 'PIN must be a 4-digit number.';
      });
      return;
    }

    if (newPin != confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final bool hasNet = await _checkInternet();
    if (!hasNet) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please connect to network.';
      });
      return;
    }

    try {
      // Save locally
      await widget.lockRepository.saveLocalConfig('pincode', false, value: newPin);
      await widget.lockRepository.saveConfiguredState('pincode', true);

      // Enable pincode lock on backend/locally if not already active
      final userIdInt = int.tryParse(widget.storageService.userId) ?? 12;
      if (!mounted) return;
      final bool syncSuccess = await widget.securityManager.enableLockState(context, userIdInt, 'pincode');

      setState(() {
        _isLoading = false;
      });

      if (syncSuccess) {
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage = 'Failed to update PIN settings on server. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update PIN settings. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    String title = 'Reset Security PIN';

    if (_isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_step == 'email') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We will send a 6-digit verification code to your registered email to authorize resetting your security PIN.',
            style: GoogleFonts.outfit(fontSize: 13.sp, color: Colors.grey),
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Registered Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _sendOtp,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Send Verification Code', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else if (_step == 'otp') {
      title = 'Verify Gmail OTP';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the 6-digit code sent to $_targetEmail:',
            style: GoogleFonts.outfit(fontSize: 13.sp, color: Colors.grey),
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 20.sp, fontWeight: FontWeight.bold, letterSpacing: 8.0),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Verify & Proceed', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 10.h),
          TextButton(
            onPressed: () {
              setState(() {
                _step = 'email';
              });
            },
            child: Text('Back to Email', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else {
      title = 'Set New PIN';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter a new 4-digit code to lock your vault:',
            style: GoogleFonts.outfit(fontSize: 13.sp, color: Colors.grey),
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 20.sp, fontWeight: FontWeight.bold, letterSpacing: 8.0),
            decoration: InputDecoration(
              labelText: 'New 4-Digit PIN',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 14.h),
          TextField(
            controller: _confirmPinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 20.sp, fontWeight: FontWeight.bold, letterSpacing: 8.0),
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _savePin,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Save & Unlock', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 20.sp, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty) ...[
                Text(
                  _errorMessage,
                  style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13.sp, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              content,
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
