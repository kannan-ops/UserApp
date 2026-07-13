import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enquiry_app/models/login_history_model.dart';
import 'package:enquiry_app/services/api_service.dart';
import 'package:enquiry_app/services/security_service.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';

class LoginHistoryScreen extends StatefulWidget {
  final int userId;

  const LoginHistoryScreen({super.key, this.userId = 1});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final SecurityService _securityService = SecurityService(ApiService());

  List<LoginHistoryModel> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    print("Screen Open: Login History Screen opened");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchHistory();
      }
    });
  }

  Future<void> _fetchHistory() async {
    print("Loading Start: loading shown");
    print("API started: Login history query in progress...");

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _securityService.getLoginHistory(widget.userId);

      print("Loading Stop: loading hidden");
      print("API Success: Login history successfully loaded");

      if (mounted) {
        setState(() {
          _history = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Loading Stop: loading hidden");
      print("API Failure: Login history query failed");

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        _showErrorSnackBar(
          'Registry Error',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  void _showErrorSnackBar(String title, String message) {
    print(
      "SnackBar shown: displaying error popup with title: '$title' and message: '$message'",
    );

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
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String year = dt.year.toString();

    int hour = dt.hour;
    final String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;
    final String minute = dt.minute.toString().padLeft(2, '0');

    return '$day-$month-$year ${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'fingerprint':
        return Icons.fingerprint_rounded;
      case 'grid card':
      case 'grid_card':
        return Icons.grid_view_rounded;
      case 'security tab':
      case 'security_tab':
        return Icons.shield_rounded;
      case 'face lock':
      case 'face_lock':
        return Icons.face_retouching_natural_rounded;
      case 'pattern lock':
      case 'pattern':
        return Icons.gesture_rounded;
      case 'pin code':
      case 'pincode':
        return Icons.dialpad_rounded;
      default:
        return Icons.lock_open_rounded;
    }
  }

  Color _getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'fingerprint':
        return AppConstants.accentColor;
      case 'grid card':
      case 'grid_card':
        return const Color(0xFF6366F1);
      case 'security tab':
      case 'security_tab':
        return const Color(0xFF8B5CF6);
      case 'face lock':
      case 'face_lock':
        return const Color(0xFFEC4899);
      case 'pattern lock':
      case 'pattern':
        return AppTheme.warningColor;
      case 'pin code':
      case 'pincode':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            'Security TelemetryLogs',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              print("Button Click: Back arrow button clicked");
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Force Reload Feed',
              onPressed: () {
                print("Button Click: Refresh/Reload button clicked");
                _fetchHistory();
              },
            ),
          ],
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
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _history.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async {
                      print("Button Click: Pull-to-refresh action triggered");
                      await _fetchHistory();
                    },
                    color: Theme.of(context).colorScheme.primary,
                    child: _buildHistoryList(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56.r,
            height: 56.r,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.08),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16.h),
          Text(
            'Decrypting Clearance Logs...',
            style: GoogleFonts.outfit(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.errorColor,
                size: 44.r,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Secure Sync Terminated',
              style: GoogleFonts.outfit(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'No response could be decrypted from the Node.js server. Verify that the backend is running at https://lockscreen.srivagroups.in/api.',
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                print("Button Click: Retry verification button clicked");
                _fetchHistory();
              },
              icon: const Icon(Icons.sync_rounded),
              label: Text(
                'Retry Verification',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.playlist_remove_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 48.r,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Historical Clearance Logs',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'No local logins or biometric handshakes have been synchronized with the Node.js backend yet.',
              style: GoogleFonts.outfit(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                print("Button Click: Sync telemetry button clicked");
                _fetchHistory();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Sync Telemetry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          padding: EdgeInsets.all(18.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: AppTheme.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VAULT TELEMETRY DATA',
                      style: GoogleFonts.outfit(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${_history.length} Handshakes Verified',
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 6.h),
          child: Text(
            'CHRONOLOGICAL SECURITY FEED',
            style: GoogleFonts.outfit(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final log = _history[index];
              final iconColor = _getMethodColor(log.method);
              final isSuccess = log.status.toLowerCase() == 'success';

              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 8.h,
                  ),
                  leading: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getMethodIcon(log.method),
                      color: iconColor,
                      size: 24.r,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        log.method,
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? AppConstants.accentColor.withOpacity(0.1)
                              : AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          log.status.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: isSuccess
                                ? AppConstants.accentColor
                                : AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      _formatDateTime(log.time),
                      style: GoogleFonts.outfit(
                        fontSize: 12.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
