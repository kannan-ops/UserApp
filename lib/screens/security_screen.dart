import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:local_auth/local_auth.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/services/security_manager.dart';
import 'package:enquiry_app/screens/otp_setup_screen.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  final bool isStandalone;

  const SecurityScreen({super.key, this.isStandalone = false});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  late StorageService _storageService;
  late BiometricService _biometricService;

  bool _isBiometricSupported = false;
  bool _isBiometricEnrolled = false;
  bool _hasFingerprintHardware = false;
  bool _hasFaceHardware = false;
  bool _hasIrisHardware = false;
  final Set<String> _processingKeys = {};

  @override
  void initState() {
    super.initState();
    _storageService = ref.read(storageServiceProvider);
    _biometricService = ref.read(biometricServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkHardwareBiometrics();
        final int userId = int.tryParse(_storageService.userId) ?? 12;
        ref.read(securityManagerProvider).initializeSecurity(userId);
      }
    });
  }

  void _checkHardwareBiometrics() async {
    _isBiometricSupported = await _biometricService.isHardwareSupported();
    if (_isBiometricSupported) {
      _isBiometricEnrolled = await _biometricService.hasEnrolledBiometrics();
      final available = await _biometricService.getAvailableBiometrics();

      debugPrint(
        'DEBUG [CircuitPoint]: Available Biometrics on target device = $available',
      );

      setState(() {
        if (available.isNotEmpty) {
          _hasFingerprintHardware =
              available.contains(BiometricType.fingerprint) ||
              available.contains(BiometricType.strong);
          _hasFaceHardware =
              available.contains(BiometricType.face) ||
              available.contains(BiometricType.weak);
          _hasIrisHardware = available.contains(BiometricType.iris);
        } else {
          _hasFingerprintHardware = true;
          _hasFaceHardware = true;
          _hasIrisHardware = false;
        }
      });
    } else {
      setState(() {
        _hasFingerprintHardware = false;
        _hasFaceHardware = false;
        _hasIrisHardware = false;
      });
    }
  }

  Future<void> _handleToggleChange(
    BuildContext context,
    String key,
    bool newValue,
  ) async {
    if (_processingKeys.contains(key)) return;

    final securityManager = ref.read(securityManagerProvider);
    final isConfigured = securityManager.isLockConfigured(key);
    final int userId = int.tryParse(_storageService.userId) ?? 12;

    if (key == 'is_app_lock_enabled' && newValue) {
      final bool hasActiveLock =
          securityManager.isLockEnabled('pincode') ||
          securityManager.isLockEnabled('pattern_lock') ||
          securityManager.isLockEnabled('fingerprint') ||
          securityManager.isLockEnabled('face_lock');

      if (!hasActiveLock) {
        _showSnackBar(
          'Please set up a PIN, Pattern, or Biometrics first!',
          AppTheme.warningColor,
          Icons.warning_amber_rounded,
        );
        return;
      }
    }

    setState(() {
      _processingKeys.add(key);
    });

    debugPrint("========== SECURITY CONSOLE ==========");
    debugPrint("========== TOGGLE ACTION ==========");
    debugPrint("Field: $key");
    debugPrint("Old Value: ${newValue ? 'disable' : 'enable'}");
    debugPrint("New Value: ${newValue ? 'enable' : 'disable'}");

    debugPrint("Loading started...");

    if (newValue) {
      bool needsSetup =
          (key == 'pincode' ||
          key == 'pattern_lock' ||
          key == 'grid_card' ||
          key == 'sms_otp' ||
          key == 'whatsapp_otp' ||
          key == 'mail_otp' ||
          key == 'fingerprint' ||
          key == 'face_lock');
      if (needsSetup) {
        debugPrint("Lock not configured. Triggering setup...");
        final bool success = await securityManager.configureLock(context, key);
        if (!success) {
          debugPrint("Configuration failed/aborted by user.");
          _showSnackBar(
            'Setup cancelled.',
            AppTheme.errorColor,
            Icons.error_outline_rounded,
          );
          debugPrint("Reverting toggle state...");
          debugPrint("Loading ended...");
          setState(() {
            _processingKeys.remove(key);
          });
          return;
        }
        debugPrint("Configuration successful for $key.");
      }
    }

    debugPrint("Opening OTP verification modal...");
    bool? otpVerified = false;
    try {
      otpVerified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OtpSetupScreen(
            lockKey: 'mail_otp',
            lockTitle:
                '${newValue ? 'Enable' : 'Disable'} ${_getDisplayName(key)}',
            isChallenge: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint("OTP verification screen error: $e");
    }

    debugPrint(
      "OTP verify status: ${otpVerified == true ? 'SUCCESS' : 'FAILED/CANCELLED'}",
    );

    if (otpVerified == true) {
      debugPrint("Updating security setting...");
      final Map<String, String> body = {
        'user_id': userId.toString(),
        key: newValue ? 'enable' : 'disable',
      };
      debugPrint("Request Body: ${jsonEncode(body)}");

      bool success = false;
      try {
        if (newValue) {
          success = await securityManager.enableLockState(context, userId, key);
        } else {
          success = await securityManager.disableLock(context, userId, key);
        }
      } catch (e) {
        debugPrint("API request failed with error: $e");
      }

      if (success) {
        debugPrint("Update Success");
        _syncLegacyStorage(key, newValue);
        _showSnackBar(
          '${_getDisplayName(key)} ${newValue ? 'enabled and active!' : 'deactivated.'}',
          newValue ? AppConstants.accentColor : AppTheme.warningColor,
          newValue ? Icons.check_circle_rounded : Icons.lock_open_rounded,
        );
      } else {
        debugPrint("Update Failed: Sync with backend failed");
        _showSnackBar(
          'Failed to save security settings to backend.',
          AppTheme.errorColor,
          Icons.error_outline_rounded,
        );
        debugPrint("Reverting toggle state...");
      }
    } else {
      debugPrint("Reverting toggle state...");
      _showSnackBar(
        'Verification cancelled.',
        AppTheme.errorColor,
        Icons.cancel_outlined,
      );
    }

    debugPrint("Loading ended...");
    setState(() {
      _processingKeys.remove(key);
    });
  }

  void _syncLegacyStorage(String key, bool value) async {
    if (key == 'pincode') {
      await _storageService.setPinEnabled(value);
      if (!value) await _storageService.setPinCode('');
    } else if (key == 'pattern_lock') {
      await _storageService.setPatternEnabled(value);
      if (!value) await _storageService.setPatternCode('');
    } else if (key == 'fingerprint') {
      await _storageService.setFingerprintEnabled(value);
      await _storageService.setBiometricEnabled(
        value || _storageService.isFaceLockEnabled,
      );
    } else if (key == 'face_lock') {
      await _storageService.setFaceLockEnabled(value);
      await _storageService.setBiometricEnabled(
        value || _storageService.isFingerprintEnabled,
      );
    } else if (key == 'grid_card') {
      await _storageService.setGridLockEnabled(value);
    } else if (key == 'ask_biometrics_on_open') {
      await _storageService.setAskBiometricsOnOpen(value);
      await _storageService.setAppLockEnabled(value);
    } else if (key == 'ask_biometrics_before_security') {
      await _storageService.setAskBiometricsBeforeSecurity(value);
    } else if (key == 'ask_biometrics_before_logout') {
      await _storageService.setAskBiometricsBeforeLogout(value);
    } else if (key == 'is_app_lock_enabled') {
      await _storageService.setAppLockEnabled(value);
    }
  }

  String _getDisplayName(String key) {
    switch (key) {
      case 'pincode':
        return 'PIN Code Lock';
      case 'pattern_lock':
        return 'Pattern Lock';
      case 'fingerprint':
        return 'Fingerprint Identification';
      case 'face_lock':
        return 'Face ID Identification';
      case 'grid_card':
        return 'Multi-Factor Grid Card';
      case 'security_tab':
        return 'Security Tab Lock';
      case 'sms_otp':
        return 'SMS OTP Authentication';
      case 'whatsapp_otp':
        return 'WhatsApp OTP Authentication';
      case 'mail_otp':
        return 'Mail OTP Authentication';
      case 'ask_biometrics_on_open':
        return 'Challenge on App Reopen';
      case 'ask_biometrics_before_security':
        return 'Challenge on Security Page';
      case 'ask_biometrics_before_logout':
        return 'Challenge on Terminal Logout';
      case 'is_app_lock_enabled':
        return 'Standard Reopen App Lock';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _showSnackBar(String text, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12.w),
            Expanded(child: Text(text, style: GoogleFonts.outfit())),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSecurityToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isConfigured,
    required VoidCallback onTap,
    required BuildContext context,
    Widget? trailingWidget,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            size: 24.w,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        trailing: trailingWidget,
      ),
    );
  }

  Widget _buildLockCard(
    String key,
    IconData icon,
    String title,
    SecurityManager securityManager,
  ) {
    final bool isConfigured = securityManager.isLockConfigured(key);
    final bool isEnabled = securityManager.isLockEnabled(key);
    final bool isProcessing = _processingKeys.contains(key);

    String subtitle;
    if (isEnabled) {
      subtitle = 'Active. Tap to disable.';
    } else if (isConfigured) {
      subtitle = 'Configured. Tap to enable.';
    } else {
      subtitle = 'Not configured. Tap to setup.';
    }

    final Widget trailingWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isConfigured && (key == 'pincode' || key == 'pattern_lock')) ...[
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20.w,
            ),
            onPressed: () async {
              debugPrint("Reconfiguring $key...");
              final bool success = await securityManager.configureLock(
                context,
                key,
              );
              if (success) {
                _showSnackBar(
                  '${_getDisplayName(key)} updated successfully!',
                  AppConstants.accentColor,
                  Icons.check_circle_rounded,
                );
              }
            },
          ),
          SizedBox(width: 4.w),
        ],
        isProcessing
            ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            : Switch(
                value: isEnabled,
                onChanged: (val) => _handleToggleChange(context, key, val),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
      ],
    );

    return _buildSecurityToggleTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      isActive: isEnabled,
      isConfigured: isConfigured,
      onTap: () => _handleToggleChange(context, key, !isEnabled),
      context: context,
      trailingWidget: trailingWidget,
    );
  }

  Widget _buildTriggerCard(
    String key,
    IconData icon,
    String title,
    SecurityManager securityManager,
  ) {
    final bool hasBiometrics =
        securityManager.isLockConfigured('fingerprint') ||
        securityManager.isLockConfigured('face_lock');
    final bool isEnabled = securityManager.isLockEnabled(key);
    final bool isProcessing = _processingKeys.contains(key);

    final Widget trailingWidget = isProcessing
        ? SizedBox(
            width: 24.w,
            height: 24.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : Switch(
            value: isEnabled && hasBiometrics,
            onChanged: (val) {
              if (!hasBiometrics) {
                _showSnackBar(
                  'Please set up Fingerprint or Face ID first!',
                  AppTheme.warningColor,
                  Icons.warning_amber_rounded,
                );
                return;
              }
              _handleToggleChange(context, key, val);
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          );

    return _buildSecurityToggleTile(
      icon: icon,
      title: title,
      subtitle: hasBiometrics
          ? 'Tap to toggle'
          : 'Requires biometrics setup first',
      isActive: isEnabled,
      isConfigured: true,
      onTap: () {
        if (!hasBiometrics) {
          _showSnackBar(
            'Please set up Fingerprint or Face ID first!',
            AppTheme.warningColor,
            Icons.warning_amber_rounded,
          );
          return;
        }
        _handleToggleChange(context, key, !isEnabled);
      },
      context: context,
      trailingWidget: trailingWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final securityManager = ref.watch(securityManagerProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        appBar: widget.isStandalone
            ? AppBar(
                title: const Text('Security Terminal'),
                bottom: securityManager.isSyncing
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(4),
                        child: LinearProgressIndicator(),
                      )
                    : null,
              )
            : AppBar(
                title: const Text('Security Console'),
                elevation: 0,
                bottom: securityManager.isSyncing
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(4),
                        child: LinearProgressIndicator(),
                      )
                    : null,
              ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isStandalone) ...[
                  Text(
                    'Security Console',
                    style: GoogleFonts.outfit(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Enforce and adjust active local vault authorization keys',
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],

                _buildSecurityStatusCard(context),

                SizedBox(height: 20.h),

                _buildHardwareProfilesCard(context),

                SizedBox(height: 24.h),

                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                  child: Text(
                    'PRIMARY AUTHORIZATION LOCKS',
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                _buildLockCard(
                  'pincode',
                  Icons.dialpad_rounded,
                  '4 Digit PIN Code Lock',
                  securityManager,
                ),

                _buildLockCard(
                  'pattern_lock',
                  Icons.gesture_rounded,
                  'Pattern Lock Grid',
                  securityManager,
                ),

                SizedBox(height: 16.h),

                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                  child: Text(
                    'REAL BIOMETRIC IDENTIFICATION',
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                _buildLockCard(
                  'fingerprint',
                  Icons.fingerprint_rounded,
                  'Fingerprint Authentication',
                  securityManager,
                ),

                _buildLockCard(
                  'face_lock',
                  Icons.face_retouching_natural_rounded,
                  'Face ID Authentication',
                  securityManager,
                ),

                SizedBox(height: 16.h),

                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                  child: Text(
                    'BIOMETRIC CHALLENGE TRIGGERS',
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                _buildTriggerCard(
                  'ask_biometrics_on_open',
                  Icons.open_in_new_rounded,
                  'Challenge on App Reopen',
                  securityManager,
                ),

                _buildTriggerCard(
                  'ask_biometrics_before_security',
                  Icons.admin_panel_settings_rounded,
                  'Challenge on Security Page',
                  securityManager,
                ),

                _buildTriggerCard(
                  'ask_biometrics_before_logout',
                  Icons.logout_rounded,
                  'Challenge on Terminal Logout',
                  securityManager,
                ),

                SizedBox(height: 16.h),

                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                  child: Text(
                    'SECONDARY ENCRYPTED SHIELDS',
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                _buildLockCard(
                  'grid_card',
                  Icons.grid_view_rounded,
                  'Multi-Factor Grid Card',
                  securityManager,
                ),

                _buildLockCard(
                  'is_app_lock_enabled',
                  Icons.app_blocking_rounded,
                  'Standard Reopen App Lock',
                  securityManager,
                ),

                _buildLockCard(
                  'security_tab',
                  Icons.shield_rounded,
                  'Security Tab Authentication',
                  securityManager,
                ),

                SizedBox(height: 16.h),

                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                  child: Text(
                    'SECURE ONE-TIME PASSWORD LOCKS',
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                _buildLockCard(
                  'sms_otp',
                  Icons.sms_outlined,
                  'SMS OTP Authentication',
                  securityManager,
                ),

                _buildLockCard(
                  'whatsapp_otp',
                  Icons.chat_bubble_outline_rounded,
                  'WhatsApp OTP Authentication',
                  securityManager,
                ),

                _buildLockCard(
                  'mail_otp',
                  Icons.alternate_email_rounded,
                  'Mail OTP Authentication',
                  securityManager,
                ),

                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHardwareProfilesCard(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget profileIndicator(String name, bool detected) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: detected
              ? AppConstants.accentColor.withOpacity(0.08)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: detected
                ? AppConstants.accentColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: detected ? AppConstants.accentColor : Colors.grey,
                boxShadow: detected
                    ? [
                        BoxShadow(
                          color: AppConstants.accentColor.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: detected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.biotech_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20.r,
                ),
                SizedBox(width: 8.w),
                Text(
                  'DETECTED BIOMETRIC HARDWARE',
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                profileIndicator('Fingerprint Sensor', _hasFingerprintHardware),
                profileIndicator('Face Scanner', _hasFaceHardware),
                profileIndicator('Iris Scanner', _hasIrisHardware),
              ],
            ),
            if (!_isBiometricSupported) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.redAccent,
                    size: 14,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'No biometric hardware supported or detected on this device.',
                      style: GoogleFonts.outfit(
                        fontSize: 11.sp,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!_isBiometricEnrolled) ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningColor,
                          size: 16,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Setup Instructions Required:',
                          style: GoogleFonts.outfit(
                            fontSize: 12.sp,
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'â€¢ Go to Phone Settings -> Security -> Fingerprint & enroll a fingerprint.\n'
                      'â€¢ Set up a secure system screen lock (PIN, Pattern, or Password).\n'
                      'â€¢ Ensure biometric app permissions are enabled if prompted by the OS.',
                      style: GoogleFonts.outfit(
                        fontSize: 11.sp,
                        height: 1.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityStatusCard(BuildContext context) {
    final securityManager = ref.watch(securityManagerProvider);

    int activeLocksCount = 0;
    if (securityManager.isLockEnabled('pincode')) activeLocksCount++;
    if (securityManager.isLockEnabled('pattern_lock')) activeLocksCount++;
    if (securityManager.isLockEnabled('fingerprint') ||
        securityManager.isLockEnabled('face_lock'))
      activeLocksCount++;

    String statusText = 'VULNERABLE';
    Color statusColor = Colors.redAccent;
    double progress = 0.15;

    if (activeLocksCount == 1) {
      statusText = 'BASIC';
      statusColor = AppTheme.warningColor;
      progress = 0.45;
    } else if (activeLocksCount == 2) {
      statusText = 'OPTIMAL';
      statusColor = Theme.of(context).colorScheme.primary;
      progress = 0.75;
    } else if (activeLocksCount >= 3) {
      statusText = 'MAXIMUM';
      statusColor = AppConstants.accentColor;
      progress = 1.0;
    }

    return Card(
      color: statusColor.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Row(
          children: [
            SizedBox(
              width: 74.r,
              height: 74.r,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.08),
                    color: statusColor,
                  ),
                  Icon(Icons.security_rounded, color: statusColor, size: 26.w),
                ],
              ),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHIELD LEVEL STATUS',
                    style: GoogleFonts.outfit(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: statusColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$statusText PROTECTION',
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '$activeLocksCount of 3 hardware authorization locks currently configured.',
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
          ],
        ),
      ),
    );
  }
}
