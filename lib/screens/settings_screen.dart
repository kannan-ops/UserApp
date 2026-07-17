import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/services/auth_service.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/theme/theme_provider.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/screens/login_screen.dart';
import 'package:enquiry_app/screens/two_step_auth_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool isStandalone;

  const SettingsScreen({super.key, this.isStandalone = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late StorageService _storageService;

  bool _notificationsEnabled = true;
  bool _notificationSoundEnabled = true;
  String _selectedLanguage = 'English';
  bool _autoSync = true;

  @override
  void initState() {
    super.initState();
    _storageService = ref.read(storageServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSettings();
      }
    });
  }

  void _loadSettings() {
    setState(() {
      _notificationsEnabled = _storageService.notificationsEnabled;
      _notificationSoundEnabled = _storageService.notificationSoundEnabled;
      _selectedLanguage = _storageService.language;
      _autoSync = _storageService.autoSync;
    });
  }

  void _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await _storageService.setNotificationsEnabled(value);
  }

  void _toggleNotificationSound(bool value) async {
    setState(() {
      _notificationSoundEnabled = value;
    });
    await _storageService.setNotificationSoundEnabled(value);
  }

  void _toggleAutoSync(bool value) async {
    setState(() {
      _autoSync = value;
    });
    await _storageService.setAutoSync(value);
  }

  void _changeLanguage(String? newLanguage) async {
    if (newLanguage != null) {
      setState(() {
        _selectedLanguage = newLanguage;
      });
      await _storageService.setLanguage(newLanguage);
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 38,
                    color: Colors.redAccent,
                  ),
                ),
                SizedBox(height: 20.h),

                Text(
                  'Terminate Session?',
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Logging out will end your current secure session clearance. You will need to re-verify credentials next time.',
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28.h),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Stay Secure',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final biometricService = ref.read(biometricServiceProvider);
                          final authService = ref.read(authServiceProvider);

                          Navigator.pop(context);

                          if (_storageService.askBiometricsBeforeLogout) {
                            final result = await biometricService.authenticate(
                              reason:
                                  'Verify identity to authorize session termination',
                            );
                            if (!result.success) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Logout Aborted: ${result.message}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                          }

                          print("========== LOGOUT DEBUG (BEFORE) ==========");
                          await authService.logout();

                          final storage = _StorageDebugAdapter();
                          await storage.delete(key: 'token');

                          print("========== LOGOUT DEBUG ==========");
                          print("TOKEN REMOVED");
                          print("USER LOGGED OUT");
                          print("NAVIGATING TO LOGIN PAGE");
                          print("=================================");

                          if (!mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'End Session',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(children: children),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required BuildContext context,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20.w,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(
          fontSize: 11.sp,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
      activeThumbColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProviderVal = ref.watch(themeProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        appBar: widget.isStandalone
            ? AppBar(title: const Text('System Settings'))
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isStandalone) ...[
                  Text(
                    'System Console',
                    style: GoogleFonts.outfit(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Configure environment details and operational parameters',
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],

                _buildSectionCard(
                  title: 'Aesthetics & Theme',
                  context: context,
                  children: [
                    _buildSwitchRow(
                      icon: isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: 'Dark Mode Console',
                      subtitle:
                          'Switch between sleek night and standard light views',
                      value: themeProviderVal.isDarkMode,
                      onChanged: (val) {
                        themeProviderVal.toggleTheme();
                      },
                      context: context,
                    ),
                  ],
                ),

                _buildSectionCard(
                  title: 'Operational Settings',
                  context: context,
                  children: [
                    _buildSwitchRow(
                      icon: Icons.notifications_active_outlined,
                      title: 'Security Notifications',
                      subtitle: 'Alert on system audits or new security clears',
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      context: context,
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 20),

                    _buildSwitchRow(
                      icon: Icons.volume_up_rounded,
                      title: 'Notification Sound',
                      subtitle: 'Play sound when new items arrive in feed',
                      value: _notificationSoundEnabled,
                      onChanged: _toggleNotificationSound,
                      context: context,
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 20),

                    _buildSwitchRow(
                      icon: Icons.sync_rounded,
                      title: 'Auto Cloud Sync',
                      subtitle: 'Back up telemetry states in offline logs',
                      value: _autoSync,
                      onChanged: _toggleAutoSync,
                      context: context,
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 20),

                    ListTile(
                      onTap: () {
                        final int userIdInt =
                            int.tryParse(_storageService.userId) ?? 12;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TwoStepAuthSettingsScreen(userId: userIdInt),
                          ),
                        );
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.sync_problem_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20.w,
                        ),
                      ),
                      title: Text(
                        'MFA Backend Synchronization',
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Manage required multi-factor settings',
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 20),

                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20.w,
                        ),
                      ),
                      title: Text(
                        'Console Language',
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Operational reporting display format',
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          underline: const SizedBox(),
                          alignment: Alignment.centerRight,
                          icon: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          items: AppConstants.availableLanguages.map((lang) {
                            return DropdownMenuItem<String>(
                              value: lang,
                              child: Text(
                                lang,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: _changeLanguage,
                        ),
                      ),
                    ),
                  ],
                ),

                _buildSectionCard(
                  title: 'Device Metadata',
                  context: context,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20.w,
                        ),
                      ),
                      title: Text(
                        'Firmware Version',
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        'v3.5.2-RELEASE',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),

                Card(
                  color: Colors.redAccent.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.redAccent, width: 0.8),
                  ),
                  child: ListTile(
                    onTap: () => _showLogoutConfirmation(context),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Logout Terminal',
                      style: GoogleFonts.outfit(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: Text(
                      'Immediately clear session authorization credentials',
                      style: GoogleFonts.outfit(
                        fontSize: 11.sp,
                        color: Colors.redAccent.withOpacity(0.6),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageDebugAdapter {
  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'token') {
      await prefs.remove('auth_token');
    }
  }

  Future<void> write({required String key, required dynamic value}) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'token') {
      await prefs.setString('auth_token', value?.toString() ?? '');
    }
  }

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'token') {
      return prefs.getString('auth_token');
    }
    return null;
  }
}

typedef LoginPage = LoginScreen;
