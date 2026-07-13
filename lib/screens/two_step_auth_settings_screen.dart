import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/models/security_setting.dart';
import 'package:enquiry_app/widgets/security_card.dart';
import 'package:enquiry_app/providers/security_settings_provider.dart';
import 'package:enquiry_app/screens/security_setup_screen.dart';

class TwoStepAuthSettingsScreen extends ConsumerStatefulWidget {
  final int userId;

  const TwoStepAuthSettingsScreen({super.key, this.userId = 12});

  @override
  ConsumerState<TwoStepAuthSettingsScreen> createState() =>
      _TwoStepAuthSettingsScreenState();
}

class _TwoStepAuthSettingsScreenState extends ConsumerState<TwoStepAuthSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(securitySettingsProvider).fetchSettings(userId: widget.userId, force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(securitySettingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F131E) : const Color(0xFFF8FAFC),
        ),
        child: SafeArea(
          child: provider.isLoading && provider.settings.isEmpty
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.fetchSettings(
                    userId: widget.userId,
                    force: true,
                  ),
                  color: Theme.of(context).colorScheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 12.h),

                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                              color: Theme.of(context).colorScheme.onSurface,
                              iconSize: 18.w,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Security / Enable-Disable',
                              style: GoogleFonts.outfit(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24.h),

                        _buildGradientBannerCard(context),

                        SizedBox(height: 24.h),

                        Padding(
                          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
                          child: Text(
                            'DYNAMIC HARDWARE & NETWORK PROTOCOLS',
                            style: GoogleFonts.outfit(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.settings.length,
                          itemBuilder: (context, index) {
                            final SecuritySetting setting =
                                provider.settings[index];
                            final bool isPending =
                                provider.pendingKey == setting.key;

                            return SecurityCard(
                              setting: setting,
                              isPending: isPending,
                              onChanged: (val) async {
                                final success = await provider.updateSetting(
                                  setting.key,
                                  val,
                                  userId: widget.userId,
                                );
                                if (mounted) {
                                  if (success) {
                                    _showFeedbackSnackBar(
                                      title: 'Status Synchronized',
                                      message:
                                          '${setting.title} ${val ? 'Enabled' : 'Disabled'} Successfully',
                                      color: AppConstants.accentColor,
                                      icon: Icons.verified_rounded,
                                    );
                                  } else {
                                    _showFeedbackSnackBar(
                                      title: 'Sync Failed',
                                      message:
                                          provider.errorMessage ??
                                          'Could not synchronize changes.',
                                      color: AppTheme.errorColor,
                                      icon: Icons.cloud_off_rounded,
                                    );
                                  }
                                }
                              },
                              onConfigure: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SecuritySetupScreen(
                                      settingKey: setting.key,
                                      title: setting.title,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        SizedBox(height: 18.h),

                        _buildLiveConnectedCard(context),

                        SizedBox(height: 24.h),

                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => provider.fetchSettings(
                                  userId: widget.userId,
                                  force: true,
                                ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 0,
                          ),
                          child: provider.isLoading
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.sync_rounded),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Refresh Sync Settings',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGradientBannerCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: const LinearGradient(
          colors: AppTheme.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MFA OVERRIDE ENGINE',
                style: GoogleFonts.outfit(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white70,
                ),
              ),
              Icon(
                Icons.shield_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 22.w,
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Text(
            'Dynamically Configure Clearances',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Enabling a vault factor immediately synchronizes active multi-factor challenges with Node.js databases.',
            style: GoogleFonts.outfit(
              fontSize: 11.sp,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveConnectedCard(BuildContext context) {
    return Card(
      color: AppConstants.accentColor.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(
          color: AppConstants.accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_done_rounded,
                color: AppConstants.accentColor,
                size: 24.w,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Telemetry Connected',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Changes synchronize with Node.js in real-time.',
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

  void _showFeedbackSnackBar({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24.w),
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
                      fontSize: 13.sp,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
