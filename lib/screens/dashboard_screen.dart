import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';

import 'package:enquiry_app/chartfile/getbulk.dart';
import 'package:enquiry_app/chartfile/getenq.dart';
import 'package:enquiry_app/chartfile/getsector.dart';
import 'package:enquiry_app/chartfile/chat_threads_screen.dart';

import 'package:enquiry_app/screens/profile_screen.dart';
import 'package:enquiry_app/screens/settings_screen.dart';
import 'package:enquiry_app/screens/security_screen.dart';
import 'package:enquiry_app/screens/login_screen.dart';

import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/services/auth_service.dart';
import 'package:enquiry_app/services/biometric_service.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _localAvatarPath;
  String? _locationName;
  String? _userName;

  @override
  void initState() {
    super.initState();
    print("========== DASHBOARD ACCESS GRANTED ==========");
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final storageService = ref.read(storageServiceProvider);
    setState(() {
      _localAvatarPath = prefs.getString('persistent_profile_photo_path');
      _locationName = prefs.getString('user_location_name');
      _userName = storageService.userName;
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final storageService = ref.read(storageServiceProvider);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) {
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
                          Navigator.pop(dialogContext);
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

                          Navigator.pop(dialogContext);

                          if (storageService.askBiometricsBeforeLogout) {
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

                          final prefsInstance =
                              await SharedPreferences.getInstance();
                          await prefsInstance.remove('auth_token');

                          print("========== LOGOUT DEBUG ==========");
                          print("TOKEN REMOVED");
                          print("USER LOGGED OUT");
                          print("NAVIGATING TO LOGIN PAGE");
                          print("=================================");

                          if (!mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayName = (_userName != null && _userName!.isNotEmpty) ? _userName! : "";

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        drawer: Drawer(
          backgroundColor: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30.r,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage:
                          _localAvatarPath != null &&
                              File(_localAvatarPath!).existsSync()
                          ? FileImage(File(_localAvatarPath!)) as ImageProvider
                          : null,
                      child: _localAvatarPath == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 35.w,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    SizedBox(height: 15.h),
                    Text(
                      "WELCOME",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        letterSpacing: 2,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              ListTile(
                leading: Icon(
                  Icons.inventory_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "Bulk Order",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const getbuk()),
                  );
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.question_answer_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "Enquiry",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GetEnquiry()),
                  );
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.business_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "Sector",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GetById()),
                  );
                },
              ),

              const Divider(),

              ListTile(
                leading: Icon(
                  Icons.person_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "Profile Settings",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  _loadData();
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "System Settings",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SettingsScreen(isStandalone: true),
                    ),
                  );
                  _loadData();
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  "Lock Screen Options",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecurityScreen(),
                    ),
                  );
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(
                  "Logout",
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirmation(context);
                },
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: isDarkMode
              ? const Color(0xFF0F172A)
              : const Color(0xFF6366F1),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            "CirCuiT PoInT",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20.sp,
            ),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  _loadData();
                },
                child: CircleAvatar(
                  radius: 18.r,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage:
                      _localAvatarPath != null &&
                          File(_localAvatarPath!).existsSync()
                      ? FileImage(File(_localAvatarPath!)) as ImageProvider
                      : null,
                  child: _localAvatarPath == null
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      const Color(0xFF0B0F19),
                      const Color(0xFF111827),
                      const Color(0xFF1F2937),
                    ]
                  : [
                      const Color(0xFFF8FAFC),
                      const Color(0xFFEFF6FF),
                      const Color(0xFFE0F2FE),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(bottom: 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello, $displayName ðŸ‘‹",
                          style: GoogleFonts.outfit(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Welcome back to your control center",
                          style: GoogleFonts.outfit(
                            fontSize: 13.sp,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                        if (_locationName != null &&
                            _locationName!.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14.r,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                _locationName!,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  _buildDashboardCard(
                    context: context,
                    title: "Bulk Orders",
                    subtitle: "Process and view bulk shipments",
                    icon: Icons.inventory_rounded,
                    iconColor: const Color(0xFF6366F1),
                    actionButton: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const getbuk()),
                        );
                      },
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: Text(
                        "View Bulk Orders",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  _buildDashboardCard(
                    context: context,
                    title: "Enquiries Portal",
                    subtitle: "Manage service enquiries",
                    icon: Icons.question_answer_rounded,
                    iconColor: const Color(0xFFEC4899),
                    actionButton: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GetEnquiry()),
                        );
                      },
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: Text(
                        "View Enquiry Log",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  _buildDashboardCard(
                    context: context,
                    title: "Sector Controls",
                    subtitle: "Configure regional operational parameters",
                    icon: Icons.business_rounded,
                    iconColor: const Color(0xFF10B981),
                    actionButton: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GetById()),
                        );
                      },
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: Text(
                        "View Sector Records",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  _buildSecurityCard(
                    context: context,
                    title: "Security Setup",
                    subtitle: "Biometrics, MFA and patterns configuration",
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    actionButton: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SecurityScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: Text(
                        "Configure Security Lock",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  _buildSecurityCard(
                    context: context,
                    title: "Admin Chat Center",
                    subtitle: "View and reply to client messages and queries",
                    icon: Icons.forum_rounded,
                    iconColor: const Color(0xFF3B5BDB),
                    actionButton: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatThreadsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: Text(
                        "Open Chat Inbox",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5BDB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget actionButton,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, size: 24.r, color: iconColor),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12.sp,
                        color: isDarkMode
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(width: double.infinity, child: actionButton),
        ],
      ),
    );
  }

  Widget _buildSecurityCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget actionButton,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, size: 24.r, color: iconColor),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12.sp,
                        color: isDarkMode
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(width: double.infinity, child: actionButton),
        ],
      ),
    );
  }
}
