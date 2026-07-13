import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/providers/security_settings_provider.dart';
import 'package:enquiry_app/services/message_central_service.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/models/security_setting.dart';

class MfaVerificationScreen extends ConsumerStatefulWidget {
  final String actionDescription;

  const MfaVerificationScreen({
    super.key,
    this.actionDescription = 'verify your identity for secure clearance',
  });

  @override
  ConsumerState<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends ConsumerState<MfaVerificationScreen> {
  final MessageCentralService _mcService = MessageCentralService();
  final TextEditingController _otpController = TextEditingController();

  String _viewState = 'select';
  String _selectedMethod = '';
  String _selectedMethodFlowType = '';
  String _verificationTarget = '';

  String? _verificationId;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isVerifyingOtp = false;

  Timer? _timer;
  int _timerSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() {
      print("[KEYSTROKE LOG - OTP]: ${_otpController.text}");
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() {
      _timerSeconds = 60;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_isVerifyingOtp) return;
    _isVerifyingOtp = true;

    String contact = '';
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final storage = ref.read(storageServiceProvider);
      String countryCode = '91';

      if (_selectedMethod == 'sms_otp' || _selectedMethod == 'whatsapp_otp') {
        final fullPhone = storage.userPhone.replaceAll(RegExp(r'[^\d+]'), '');
        if (fullPhone.startsWith('+')) {
          contact = fullPhone.substring(3);
          countryCode = fullPhone.substring(1, 3);
        } else {
          contact = fullPhone;
        }
      } else {
        contact = storage.userEmail;
        countryCode = '1';
      }

      setState(() {
        _verificationTarget = contact;
      });

      print("========== OTP REQUEST ==========");
      print("Sending OTP to: $contact");

      final verificationId = await _mcService.sendOtp(
        countryCode: countryCode,
        contact: contact,
        flowType: _selectedMethodFlowType,
      );

      setState(() {
        _isLoading = false;
      });

      if (verificationId != null) {
        print("========== OTP SUCCESS ==========");
        print("OTP sent successfully");

        setState(() {
          _verificationId = verificationId;
          _viewState = 'enter_otp';
        });
        _startResendTimer();

        final isMock = await _mcService.isConfigured() == false;
        if (isMock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'DEBUG SIMULATION: Enter "123456" or "654321" to pass verification.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.indigoAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        print("========== OTP FAILED ==========");
        print("Reason: API returned null verificationId");
        setState(() {
          _errorMessage = 'Failed to send OTP code. Please try again.';
        });
      }
    } catch (e) {
      print("========== OTP FAILED ==========");
      print("Reason: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send OTP code: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifyingOtp) return;
    _isVerifyingOtp = true;

    try {
      final code = _otpController.text.trim();
      if (code.length < 4) {
        setState(() {
          _errorMessage = 'Please enter a valid OTP code.';
        });
        return;
      }

      if (_verificationId == null) {
        setState(() {
          _errorMessage = 'Verification session expired. Please resend OTP.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final success = await _mcService.validateOtp(
        verificationId: _verificationId!,
        code: code,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        _timer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 12.w),
                  const Text('MFA Verification Successful!'),
                ],
              ),
              backgroundColor: AppConstants.accentColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage =
              'Invalid OTP code entered. Please verify and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final settingsProviderVal = ref.watch(securitySettingsProvider);

    final isSmsEnabled = settingsProviderVal.settings
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
    final isWhatsappEnabled = settingsProviderVal.settings
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
    final isEmailEnabled = settingsProviderVal.settings
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

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            'Identity Verification',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (_viewState == 'enter_otp') {
                setState(() {
                  _viewState = 'select';
                  _otpController.clear();
                  _errorMessage = '';
                });
              } else {
                Navigator.pop(context, false);
              }
            },
          ),
        ),
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
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 12.h),

                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 14.r,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'SECURE TELEMETRY LINK',
                            style: GoogleFonts.outfit(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  if (_viewState == 'select') ...[
                    _buildSelectionView(
                      isSmsEnabled: isSmsEnabled,
                      isWhatsappEnabled: isWhatsappEnabled,
                      isEmailEnabled: isEmailEnabled,
                    ),
                  ] else ...[
                    _buildOtpVerificationView(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionView({
    required bool isSmsEnabled,
    required bool isWhatsappEnabled,
    required bool isEmailEnabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Verification Factor',
          style: GoogleFonts.outfit(
            fontSize: 24.sp,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          'Please select an active, enabled communication protocol to ${widget.actionDescription}',
          style: GoogleFonts.outfit(
            fontSize: 13.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 32.h),

        _buildMethodCard(
          key: 'sms_otp',
          title: 'SMS OTP Verification',
          subtitle: 'Send one-time password to your secure phone number',
          icon: Icons.sms_outlined,
          isEnabled: isSmsEnabled,
          flowType: 'SMS',
        ),

        _buildMethodCard(
          key: 'whatsapp_otp',
          title: 'WhatsApp OTP Verification',
          subtitle: 'Receive secure verification link on WhatsApp',
          icon: Icons.chat_bubble_outline_rounded,
          isEnabled: isWhatsappEnabled,
          flowType: 'WHATSAPP',
        ),

        _buildMethodCard(
          key: 'mail_otp',
          title: 'Email OTP Verification',
          subtitle: 'Validate credentials via active email inbox',
          icon: Icons.alternate_email_rounded,
          isEnabled: isEmailEnabled,
          flowType: 'EMAIL',
        ),

        if (!isSmsEnabled && !isWhatsappEnabled && !isEmailEnabled) ...[
          Container(
            margin: EdgeInsets.only(top: 24.h),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Text(
              'All OTP verification methods are currently disabled. Please enable SMS OTP, WhatsApp OTP, or Email OTP under settings to use this feature.',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMethodCard({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
    required String flowType,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!isEnabled) {
              _showDisabledMethodDialog(title);
            } else {
              setState(() {
                _selectedMethod = key;
                _selectedMethodFlowType = flowType;
              });
              _sendOtp();
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isEnabled
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.4),
                  size: 16.r,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpVerificationView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter OTP Verification Code',
          style: GoogleFonts.outfit(
            fontSize: 24.sp,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          'A secure verification code has been dispatched to your active terminal:\n$_verificationTarget',
          style: GoogleFonts.outfit(
            fontSize: 13.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 36.h),

        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: _errorMessage.isNotEmpty
                  ? Colors.redAccent
                  : Theme.of(context).colorScheme.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: GoogleFonts.outfit(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 8.0,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
          ),
        ),

        if (_errorMessage.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Text(
            _errorMessage,
            style: GoogleFonts.outfit(
              color: Colors.redAccent,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        SizedBox(height: 32.h),

        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Verify Authorization Code',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
        ),

        SizedBox(height: 24.h),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code? ",
              style: GoogleFonts.outfit(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            TextButton(
              onPressed: _canResend && !_isLoading ? _sendOtp : null,
              child: Text(
                _canResend ? 'Resend OTP' : 'Resend in ${_timerSeconds}s',
                style: GoogleFonts.outfit(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: _canResend
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDisabledMethodDialog(String title) {
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
            'Enable $title inside the active Security Settings Console first before attempting dynamic sync validations.',
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
}
