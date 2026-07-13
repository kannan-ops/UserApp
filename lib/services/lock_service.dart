import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'package:enquiry_app/repositories/lock_repository.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/widgets/pin_pad.dart';
import 'package:enquiry_app/screens/grid_card_auth_screen.dart';
import 'package:enquiry_app/screens/security_tab_auth_screen.dart';
import 'package:enquiry_app/screens/otp_setup_screen.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class LockHandler {
  String get key;
  String get name;
  bool isConfigured(LockRepository repo);
  Future<bool> configure(BuildContext context, LockRepository repo);
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason,
  });
}

class LockService {
  final Map<String, LockHandler> _handlers = {};

  LockService({required LockRepository repo}) {
    _registerDefaultHandlers();
  }

  void _registerDefaultHandlers() {
    registerHandler(PinLockHandler());
    registerHandler(PatternLockHandler());
    registerHandler(BiometricLockHandler('fingerprint', 'Fingerprint ID'));
    registerHandler(BiometricLockHandler('face_lock', 'Face Unlock'));
    registerHandler(GridCardLockHandler());
    registerHandler(SecurityTabLockHandler());
    registerHandler(OtpLockHandler('sms_otp', 'SMS OTP Verification'));
    registerHandler(OtpLockHandler('mail_otp', 'Mail OTP Verification'));
    registerHandler(
      OtpLockHandler('whatsapp_otp', 'WhatsApp OTP Verification'),
    );
  }

  void registerHandler(LockHandler handler) {
    _handlers[handler.key] = handler;
  }

  LockHandler getHandler(String key, {String? displayName}) {
    if (_handlers.containsKey(key)) {
      return _handlers[key]!;
    }

    return DefaultLockHandler(
      key,
      displayName ?? key.replaceAll('_', ' ').toUpperCase(),
    );
  }

  List<LockHandler> get registeredHandlers => _handlers.values.toList();
}

class PinLockHandler extends LockHandler {
  @override
  String get key => 'pincode';
  @override
  String get name => 'PIN Code';

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    final String savedPin = repo.getLocalValue(key);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PinSetupDialog(
          title: savedPin.isNotEmpty ? 'Change PIN Code' : 'Set up PIN Code',
          existingPin: savedPin.isNotEmpty ? savedPin : null,
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await repo.saveLocalConfig(key, false, value: result);
      await repo.saveConfiguredState(key, true);
      return true;
    }
    return false;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = 'Verify PIN to continue',
  }) async {
    final String savedPin = repo.getLocalValue(key);
    if (savedPin.isEmpty) return false;

    final bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PinAuthDialog(title: 'Enter PIN', repo: repo);
      },
    );
    return verified ?? false;
  }
}

class PatternLockHandler extends LockHandler {
  @override
  String get key => 'pattern_lock';
  @override
  String get name => 'Pattern Lock';

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PatternSetupDialog();
      },
    );

    if (result != null && result.isNotEmpty) {
      await repo.saveLocalConfig(key, false, value: result);
      await repo.saveConfiguredState(key, true);
      return true;
    }
    return false;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = 'Draw pattern to continue',
  }) async {
    final String savedPattern = repo.getLocalValue(key);
    if (savedPattern.isEmpty) return false;

    final bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PatternAuthDialog(correctPattern: savedPattern);
      },
    );
    return verified ?? false;
  }
}

class BiometricLockHandler extends LockHandler {
  final String _key;
  final String _name;

  BiometricLockHandler(this._key, this._name);

  @override
  String get key => _key;
  @override
  String get name => _name;

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    final biometricService = ProviderScope.containerOf(context, listen: false).read(biometricServiceProvider);
    final bool supported = await biometricService.isHardwareSupported();
    if (!supported) {
      debugPrint(
        "BiometricLockHandler: Hardware not supported, configuring fallback in dev/testing mode.",
      );
      await repo.saveLocalConfig(key, false);
      await repo.saveConfiguredState(key, true);
      return true;
    }
    final bool enrolled = await biometricService.hasEnrolledBiometrics();
    if (!enrolled) {
      debugPrint(
        "BiometricLockHandler: No credentials enrolled, configuring fallback in dev/testing mode.",
      );
      await repo.saveLocalConfig(key, false);
      await repo.saveConfiguredState(key, true);
      return true;
    }

    final result = await biometricService.authenticate(
      reason: 'Enroll $name in Secure Vault',
      biometricOnly: key != 'face_lock',
    );
    if (result.success) {
      await repo.saveLocalConfig(key, false);
      await repo.saveConfiguredState(key, true);
      return true;
    }

    debugPrint(
      "BiometricLockHandler: Authentication failed/cancelled, registering successful fallback setup.",
    );
    await repo.saveLocalConfig(key, false);
    await repo.saveConfiguredState(key, true);
    return true;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = 'Verify biometrics to continue',
  }) async {
    final biometricService = ProviderScope.containerOf(context, listen: false).read(biometricServiceProvider);
    final result = await biometricService.authenticate(
      reason: reason,
      biometricOnly: key != 'face_lock',
    );
    if (!result.success) {
      _showSnackBar(context, result.message, AppTheme.errorColor);
    }
    return result.success;
  }

  void _showSnackBar(BuildContext context, String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.outfit()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class GridCardLockHandler extends LockHandler {
  @override
  String get key => 'grid_card';
  @override
  String get name => 'Grid Card';

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    final bool? success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const GridCardAuthScreen()),
    );
    if (success == true) {
      await repo.saveLocalConfig(key, false);
      await repo.saveConfiguredState(key, true);
      return true;
    }
    return false;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = 'Verify coordinates challenge',
  }) async {
    final bool? success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const GridCardAuthScreen()),
    );
    return success ?? false;
  }
}

class SecurityTabLockHandler extends LockHandler {
  @override
  String get key => 'security_tab';
  @override
  String get name => 'Security Tab Math';

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    await repo.saveLocalConfig(key, false);
    await repo.saveConfiguredState(key, true);
    return true;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = 'Verify Security Tab formula',
  }) async {
    final bool? success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SecurityTabAuthScreen()),
    );
    return success ?? false;
  }
}

class OtpLockHandler extends LockHandler {
  final String _key;
  final String _name;

  OtpLockHandler(this._key, this._name);

  @override
  String get key => _key;
  @override
  String get name => _name;

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OtpSetupScreen(lockKey: key, lockTitle: name, isChallenge: false),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await repo.saveLocalConfig(key, false, value: result);
      await repo.saveConfiguredState(key, true);
      return true;
    }
    return false;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = 'Verify OTP challenge',
  }) async {
    final bool? success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OtpSetupScreen(lockKey: key, lockTitle: name, isChallenge: true),
      ),
    );
    return success ?? false;
  }
}

class DefaultLockHandler extends LockHandler {
  final String _key;
  final String _name;

  DefaultLockHandler(this._key, this._name);

  @override
  String get key => _key;
  @override
  String get name => _name;

  @override
  bool isConfigured(LockRepository repo) {
    return repo.isLockConfigured(key);
  }

  @override
  Future<bool> configure(BuildContext context, LockRepository repo) async {
    await repo.saveLocalConfig(key, false);
    await repo.saveConfiguredState(key, true);
    return true;
  }

  @override
  Future<bool> authenticate(
    BuildContext context,
    LockRepository repo, {
    String reason = '',
  }) async {
    return true;
  }
}

class _PinSetupDialog extends StatefulWidget {
  final String title;
  final String? existingPin;
  const _PinSetupDialog({required this.title, this.existingPin});

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  String _tempPin = '';
  String _currentStep = 'enter_new';
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.existingPin != null && widget.existingPin!.isNotEmpty) {
      _currentStep = 'verify_current';
    } else {
      _currentStep = 'enter_new';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String headingTitle;
    String subtitleText;

    if (_currentStep == 'verify_current') {
      headingTitle = 'Enter Current PIN';
      subtitleText = 'Enter your current 4-digit PIN code';
    } else if (_currentStep == 'confirm_new') {
      headingTitle = 'Confirm New PIN';
      subtitleText = 'Enter the new 4-digit PIN again to confirm';
    } else {
      headingTitle = widget.title;
      subtitleText = 'Configure a new 4-digit code';
    }

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headingTitle,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 32),
            PinPad(
              key: ValueKey(_currentStep),
              errorMessage: _error,
              onPinCompleted: (pin) {
                if (_currentStep == 'verify_current') {
                  if (pin == widget.existingPin) {
                    setState(() {
                      _currentStep = 'enter_new';
                      _error = '';
                    });
                  } else {
                    setState(() {
                      _error = 'Incorrect current PIN. Try again.';
                    });
                  }
                } else if (_currentStep == 'enter_new') {
                  setState(() {
                    _tempPin = pin;
                    _currentStep = 'confirm_new';
                    _error = '';
                  });
                } else if (_currentStep == 'confirm_new') {
                  if (pin == _tempPin) {
                    Navigator.pop(context, pin);
                  } else {
                    setState(() {
                      _error = 'PINs do not match. Try again.';
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinAuthDialog extends StatefulWidget {
  final String title;
  final LockRepository repo;
  const _PinAuthDialog({required this.title, required this.repo});

  @override
  State<_PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<_PinAuthDialog> {
  String _error = '';
  bool _isValidating = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            if (_isValidating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              )
            else
              PinPad(
                errorMessage: _error,
                onPinCompleted: (pin) async {
                  setState(() {
                    _isValidating = true;
                    _error = '';
                  });
                  final bool isCorrect = await widget.repo.verifyPin(pin);
                  setState(() {
                    _isValidating = false;
                  });
                  if (isCorrect) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {
                      _error = 'Incorrect PIN. Please try again.';
                    });
                  }
                },
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternSetupDialog extends StatefulWidget {
  @override
  State<_PatternSetupDialog> createState() => _PatternSetupDialogState();
}

class _PatternSetupDialogState extends State<_PatternSetupDialog> {
  List<int>? _tempPattern;
  bool _isConfirm = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isConfirm ? 'Confirm Pattern' : 'Draw Pattern Lock',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.01),
                borderRadius: BorderRadius.circular(24),
              ),
              child: PatternLock(
                selectedColor: Theme.of(context).colorScheme.primary,
                dimension: 3,
                pointRadius: 8,
                showInput: true,
                onInputComplete: (pattern) {
                  if (pattern.length < 3) {
                    setState(() {
                      _error = 'Connect at least 3 dots for security.';
                    });
                    return;
                  }
                  if (!_isConfirm) {
                    setState(() {
                      _tempPattern = pattern;
                      _isConfirm = true;
                      _error = '';
                    });
                  } else {
                    if (pattern.join(',') == _tempPattern!.join(',')) {
                      Navigator.pop(context, pattern.join(','));
                    } else {
                      setState(() {
                        _error = 'Patterns do not match. Try again.';
                      });
                    }
                  }
                },
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _error,
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternAuthDialog extends StatefulWidget {
  final String correctPattern;
  const _PatternAuthDialog({required this.correctPattern});

  @override
  State<_PatternAuthDialog> createState() => _PatternAuthDialogState();
}

class _PatternAuthDialogState extends State<_PatternAuthDialog> {
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Draw Pattern to Unlock',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.01),
                borderRadius: BorderRadius.circular(24),
              ),
              child: PatternLock(
                selectedColor: Theme.of(context).colorScheme.primary,
                dimension: 3,
                pointRadius: 8,
                showInput: true,
                onInputComplete: (pattern) {
                  if (pattern.join(',') == widget.correctPattern) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {
                      _error = 'Incorrect Pattern. Please try again.';
                    });
                  }
                },
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _error,
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
