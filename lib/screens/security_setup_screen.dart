import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class SecuritySetupScreen extends StatefulWidget {
  final String settingKey;
  final String title;

  const SecuritySetupScreen({
    super.key,
    required this.settingKey,
    required this.title,
  });

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final TextEditingController _pinController1 = TextEditingController();
  final TextEditingController _pinController2 = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController1.dispose();
    _pinController2.dispose();
    super.dispose();
  }

  void _saveSetup() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${widget.title} Configuration Saved Successfully!"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.title} Setup",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F131E) : const Color(0xFFF8FAFC),
        ),
        padding: EdgeInsets.all(24.r),
        child: SingleChildScrollView(
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
                      Icons.settings_suggest_rounded,
                      size: 48.w,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "Configure ${widget.title} Settings",
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "Adjust telemetry policies and operational credentials dynamically.",
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
              SizedBox(height: 24.h),

              if (widget.settingKey == 'pincode') ...[
                _buildPinField("Enter PIN Code", _pinController1),
                SizedBox(height: 16.h),
                _buildPinField("Confirm PIN Code", _pinController2),
              ] else if (widget.settingKey == 'fingerprint') ...[
                _buildSimulationScanner(
                  "Place Fingerprint on hardware module to scan credentials",
                ),
              ] else if (widget.settingKey == 'otp_verification') ...[
                _buildSimulationScanner(
                  "Validate active cellular transceiver sync parameters",
                ),
              ] else ...[
                _buildSimulationScanner(
                  "Sync hardware policy validation credentials dynamically",
                ),
              ],

              SizedBox(height: 32.h),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveSetup,
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
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Save Configuration',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: GoogleFonts.outfit(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(fontSize: 13.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
        counterText: "",
      ),
    );
  }

  Widget _buildSimulationScanner(String text) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_protected_setup_rounded,
            size: 40.w,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 12.h),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
