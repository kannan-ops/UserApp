import 'package:flutter/material.dart';
import 'package:enquiry_app/repositories/lock_repository.dart';
import 'package:enquiry_app/services/lock_service.dart';
import 'package:enquiry_app/screens/app_lock_screen.dart';

class SecurityManager extends ChangeNotifier {
  final LockRepository _repository;
  final LockService _lockService;

  bool _isLockScreenShowing = false;
  bool _isSyncing = false;
  static bool _isInitialized = false;
  static int? _initializedUserId;

  bool get isLockScreenShowing => _isLockScreenShowing;
  bool get isSyncing => _isSyncing;

  SecurityManager({
    required LockRepository repository,
    required LockService lockService,
  }) : _repository = repository,
       _lockService = lockService;

  static void resetInitialization() {
    _isInitialized = false;
    _initializedUserId = null;
  }

  bool isLockEnabled(String key) {
    return _repository.getLocalEnabled(key);
  }

  bool isLockConfigured(String key) {
    return _repository.isLockConfigured(key);
  }

  bool isAnyLockEnabled() {
    final List<String> lockKeys = [
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

    for (final key in lockKeys) {
      if (isLockEnabled(key)) {
        return true;
      }
    }
    return false;
  }

  Future<void> initializeSecurity(int userId) async {
    if (_isInitialized && _initializedUserId == userId) {
      debugPrint(
        "SecurityManager: Already initialized for user $userId. Skipping background sync.",
      );
      return;
    }
    _isInitialized = true;
    _initializedUserId = userId;
    _isSyncing = true;
    notifyListeners();

    try {
      final remoteSettings = await _repository.fetchLockSettings(userId);
      debugPrint(
        "SecurityManager: Successfully synced security profile. Active status: $remoteSettings",
      );
    } catch (e) {
      debugPrint(
        "SecurityManager: API sync failed during initialization, relying on secure storage: $e",
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> configureLock(BuildContext context, String key) async {
    final handler = _lockService.getHandler(key);

    final bool configured = await handler.configure(context, _repository);
    if (!configured) {
      debugPrint(
        "SecurityManager: Configuration request for $key cancelled or aborted by user.",
      );
      return false;
    }

    debugPrint("SecurityManager: Successfully configured lock: $key.");
    notifyListeners();
    return true;
  }

  Future<bool> enableLockState(
    BuildContext context,
    int userId,
    String key,
  ) async {
    _isSyncing = true;
    notifyListeners();

    final Map<String, bool> updatedSettings = {key: true};
    final bool success = await _repository.syncLockSettings(
      userId,
      updatedSettings,
    );

    if (success) {
      await _repository.saveLocalConfig(key, true);
      debugPrint(
        "SecurityManager: Successfully enabled pre-configured lock $key.",
      );
    } else {
      debugPrint("SecurityManager: Sync failed to enable lock $key.");
    }

    _isSyncing = false;
    notifyListeners();
    return success;
  }

  Future<bool> disableLock(BuildContext context, int userId, String key) async {
    _isSyncing = true;
    notifyListeners();

    final Map<String, bool> updatedSettings = {key: false};
    final bool success = await _repository.syncLockSettings(
      userId,
      updatedSettings,
    );

    if (success) {
      await _repository.deleteLocalConfig(key);
      debugPrint(
        "SecurityManager: Successfully synchronized disable state for $key on backend.",
      );
    } else {
      debugPrint(
        "SecurityManager: Sync failed for disable request, reverting.",
      );
    }

    _isSyncing = false;
    notifyListeners();
    return success;
  }

  Future<bool> authenticateUser(
    BuildContext context, {
    String reason = 'Authenticate to proceed',
  }) async {
    final List<String> priorityKeys = [
      'fingerprint',
      'face_lock',
      'pincode',
      'pattern_lock',
      'grid_card',
      'security_tab',
    ];

    for (final key in priorityKeys) {
      if (isLockEnabled(key)) {
        final handler = _lockService.getHandler(key);
        debugPrint(
          "SecurityManager: Triggering active security challenge for ${handler.name}",
        );
        final bool result = await handler.authenticate(
          context,
          _repository,
          reason: reason,
        );
        if (result) return true;
      }
    }

    for (final handler in _lockService.registeredHandlers) {
      if (isLockEnabled(handler.key) && !priorityKeys.contains(handler.key)) {
        final bool result = await handler.authenticate(
          context,
          _repository,
          reason: reason,
        );
        if (result) return true;
      }
    }

    return false;
  }

  Future<void> handleAppResume(BuildContext context, int userId) async {
    // Only lock on startup/cold boot, not on resume from background.
    return;
  }
}
