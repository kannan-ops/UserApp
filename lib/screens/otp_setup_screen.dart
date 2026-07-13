import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/services/otp_service.dart';
import 'package:enquiry_app/utils/constants.dart';

class OtpSetupScreen extends ConsumerStatefulWidget {
  final String lockKey;
  final String lockTitle;
  final bool isChallenge;

  const OtpSetupScreen({
    super.key,
    required this.lockKey,
    required this.lockTitle,
    this.isChallenge = false,
  });

  @override
  ConsumerState<OtpSetupScreen> createState() => _OtpSetupScreenState();
}

class _OtpSetupScreenState extends ConsumerState<OtpSetupScreen> {
  final MessageCentralService _mcService = MessageCentralService();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String _step = 'input';
  String? _verificationId;
  bool _isLoading = false;
  String _errorMessage = '';

  Timer? _timer;
  int _timerSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();

    final storage = ref.read(storageServiceProvider);
    if (widget.lockKey == 'mail_otp') {
      _contactController.text = storage.userEmail.isNotEmpty
          ? storage.userEmail
          : '';
    } else {
      _contactController.text = storage.userPhone.isNotEmpty
          ? storage.userPhone
          : '';
    }

    if (widget.isChallenge) {
      _step = 'verify';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendOtp();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _contactController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
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
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() {
        _errorMessage = widget.lockKey == 'mail_otp'
            ? 'Please enter a valid email address.'
            : 'Please enter a valid phone number.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    bool success = false;
    String? verificationId;

    if (widget.lockKey == 'mail_otp') {
      success = await MailOtpService.sendOtpEmail(contact);
    } else {
      final flowType = widget.lockKey == 'sms_otp' ? 'SMS' : 'WHATSAPP';

      String countryCode = '91';
      String phonePart = contact.replaceAll(RegExp(r'[^\d]'), '');
      if (phonePart.startsWith('+')) {
        phonePart = phonePart.substring(3);
        countryCode = phonePart.substring(1, 3);
      } else if (phonePart.startsWith('91') && phonePart.length > 10) {
        phonePart = phonePart.substring(2);
      }

      verificationId = await _mcService.sendOtp(
        countryCode: countryCode,
        mobileNumber: phonePart,
        flowType: flowType,
      );
      success = verificationId != null;
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _verificationId = verificationId;
        _step = 'verify';
      });
      _startTimer();
    } else {
      setState(() {
        _errorMessage =
            'Failed to send OTP code. Please check your network and try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() {
        _errorMessage = 'Please enter a valid OTP code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    bool success = false;
    final contact = _contactController.text.trim();

    if (widget.lockKey == 'mail_otp') {
      success = MailOtpService.validateMailOtp(contact, code);
    } else {
      String countryCode = '91';
      String phonePart = contact.replaceAll(RegExp(r'[^\d]'), '');
      if (phonePart.startsWith('+')) {
        phonePart = phonePart.substring(3);
        countryCode = phonePart.substring(1, 3);
      } else if (phonePart.startsWith('91') && phonePart.length > 10) {
        phonePart = phonePart.substring(2);
      }

      if (_verificationId != null) {
        success = await _mcService.validateOtp(
          countryCode: countryCode,
          mobileNumber: phonePart,
          verificationId: _verificationId!,
          code: code,
        );
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _timer?.cancel();

      if (!widget.isChallenge) {
        final storage = ref.read(storageServiceProvider);
        if (widget.lockKey == 'mail_otp') {
          await storage.setUserEmail(contact);
        } else {
          await storage.setUserPhone(contact);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    widget.isChallenge
                        ? 'Identity Verified!'
                        : '${widget.lockTitle} successfully configured!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppConstants.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, widget.isChallenge ? true : contact);
      }
    } else {
      setState(() {
        _errorMessage =
            'Invalid verification code. Please verify and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isChallenge ? "Verify Identity" : "${widget.lockTitle} Setup",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_step == 'verify' && !widget.isChallenge) {
              setState(() {
                _step = 'input';
                _otpController.clear();
                _errorMessage = '';
              });
            } else {
              Navigator.pop(context, widget.isChallenge ? false : null);
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F131E) : const Color(0xFFF8FAFC),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        widget.lockKey == 'mail_otp'
                            ? Icons.alternate_email_rounded
                            : (widget.lockKey == 'sms_otp'
                                  ? Icons.sms_outlined
                                  : Icons.chat_bubble_outline_rounded),
                        size: 48.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _step == 'input'
                            ? "Verify Communication Protocol"
                            : "Authorize OTP Code",
                        style: GoogleFonts.outfit(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        _step == 'input'
                            ? "Provide active destination credentials for secure multi-factor link validation."
                            : "Enter the secure 6-digit numeric token sent directly to ${_contactController.text}.",
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                if (_step == 'input') ...[
                  Text(
                    widget.lockKey == 'mail_otp'
                        ? "SMTP Email Destination"
                        : "MessageCentral Destination Mobile Number",
                    style: GoogleFonts.outfit(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF151B2C)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _contactController,
                      keyboardType: widget.lockKey == 'mail_otp'
                          ? TextInputType.emailAddress
                          : TextInputType.phone,
                      style: GoogleFonts.outfit(fontSize: 15.sp),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.lockKey == 'mail_otp'
                            ? "email@domain.com"
                            : "+91 9876543210",
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    "Numeric Validation Token",
                    style: GoogleFonts.outfit(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF151B2C)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: _errorMessage.isNotEmpty
                            ? Colors.redAccent
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                ],

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

                SizedBox(height: 36.h),

                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_step == 'input' ? _sendOtp : _verifyOtp),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _step == 'input'
                              ? 'Send Verification Code'
                              : 'Verify Code & Enable Lock',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                ),

                if (_step == 'verify') ...[
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive token? ",
                        style: GoogleFonts.outfit(
                          fontSize: 12.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      TextButton(
                        onPressed: _canResend && !_isLoading ? _sendOtp : null,
                        child: Text(
                          _canResend
                              ? 'Resend OTP'
                              : 'Resend in ${_timerSeconds}s',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
