import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enquiry_app/providers/security_auth_provider.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/theme/app_theme.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/screens/dashboard_screen.dart';
import 'package:enquiry_app/screens/login_screen.dart';

class SecurityTabAuthScreen extends ConsumerStatefulWidget {
  const SecurityTabAuthScreen({super.key});

  @override
  ConsumerState<SecurityTabAuthScreen> createState() => _SecurityTabAuthScreenState();
}

class _SecurityTabAuthScreenState extends ConsumerState<SecurityTabAuthScreen> {
  String _reverseSelectedOp = '-';
  int _reverseSelectedNum = 3;
  bool _reverseInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(securityAuthProvider).loadNewSession();
    });
  }

  void _showSnackBar(String text, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12.w),
            Expanded(child: Text(text)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = ref.watch(securityAuthProvider);

    if (provider.isSessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.clearSessionExpired();

        _showSnackBar(
          'Session expired. Please login again.',
          AppTheme.errorColor,
          Icons.error_outline_rounded,
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      });
    }

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
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
            child: provider.isLoading && provider.sessionCode == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Text(
                              'SECURITY TELEMETRY',
                              style: GoogleFonts.outfit(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(width: 48.w),
                          ],
                        ),
                        SizedBox(height: 20.h),

                        Text(
                          'App Authentication',
                          style: GoogleFonts.outfit(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Your secure one-time session code',
                          style: GoogleFonts.outfit(
                            fontSize: 13.sp,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 28.h),

                        _buildSessionCodeBox(context, provider),

                        SizedBox(height: 24.h),

                        if (provider.errorMessage ==
                            'Security tab authentication not available for guest users.') ...[
                          _buildGuestBlockedCard(context),
                        ] else if (!provider.isOptionVerified &&
                            !provider.optionVerificationFailed) ...[
                          _buildConfigurationFlow(context, provider),
                        ] else if (provider.optionVerificationFailed) ...[
                          _buildErrorRecoveryCard(context, provider),
                        ] else if (provider.isFormulaStepActive) ...[
                          _buildFormulaVerificationView(context, provider),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCodeBox(
    BuildContext context,
    SecurityAuthProvider provider,
  ) {
    final int code = provider.sessionCode ?? 0;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 24.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SESSION CODE',
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  code.toString().padLeft(2, '0'),
                  style: GoogleFonts.outfit(
                    fontSize: 54.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8.h,
            right: 8.w,
            child: provider.isLoading
                ? SizedBox(
                    width: 28.w,
                    height: 28.w,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 28.w,
                        minHeight: 28.w,
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () async {
                        await provider.refreshSession();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationFlow(
    BuildContext context,
    SecurityAuthProvider provider,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '1. CONFIGURE MATH SYNC KEYS',
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 18.h),

                Text(
                  'Select Number Offset',
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: provider.selectedNumber,
                      dropdownColor: isDarkMode
                          ? const Color(0xFF151B2C)
                          : Colors.white,
                      items: List.generate(10, (index) => index + 1)
                          .map(
                            (val) => DropdownMenuItem<int>(
                              value: val,
                              child: Text(
                                'Offset: $val',
                                style: GoogleFonts.outfit(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          provider.setSelectedNumber(val);
                        }
                      },
                    ),
                  ),
                ),

                SizedBox(height: 18.h),

                Text(
                  'Select Operation key',
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add (+)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: provider.operation == '+'
                              ? Theme.of(context).colorScheme.primary
                              : (isDarkMode
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.grey.withOpacity(0.1)),
                          foregroundColor: provider.operation == '+'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onPressed: () => provider.setOperation('+'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('Subtract (-)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: provider.operation == '-'
                              ? Theme.of(context).colorScheme.primary
                              : (isDarkMode
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.grey.withOpacity(0.1)),
                          foregroundColor: provider.operation == '-'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onPressed: () => provider.setOperation('-'),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),
                const Divider(),
                SizedBox(height: 14.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Calculated Sync Result:',
                      style: GoogleFonts.outfit(
                        fontSize: 13.sp,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${provider.sessionCode} ${provider.operation} ${provider.selectedNumber} = ${provider.calculatedValue}',
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                  ),
                  onPressed: () async {
                    await provider.saveConfiguration();
                    _showSnackBar(
                      'Mathematical key synchronized locally!',
                      AppConstants.accentColor,
                      Icons.save_rounded,
                    );
                  },
                  child: Text(
                    'Save Sync Configuration',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 24.h),

        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
          child: Text(
            'SELECT VERIFICATION SYNC VALUE',
            style: GoogleFonts.outfit(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.6,
          ),
          itemCount: provider.verificationOptions.length,
          itemBuilder: (context, index) {
            final option = provider.verificationOptions[index];
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? const Color(0xFF151B2C)
                    : Colors.white,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
              ),
              onPressed: () => provider.selectOption(option),
              child: Text(
                option.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildErrorRecoveryCard(
    BuildContext context,
    SecurityAuthProvider provider,
  ) {
    return Card(
      color: Colors.redAccent.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 54),
            SizedBox(height: 14.h),
            Text(
              'Incorrect option selected!',
              style: GoogleFonts.outfit(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Please click below to generate a new session code.',
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
              ),
              onPressed: () {
                setState(() {
                  _reverseInitialized = false;
                });
                provider.loadNewSession();
              },
              child: Text(
                'Generate New Code',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaVerificationView(
    BuildContext context,
    SecurityAuthProvider provider,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!_reverseInitialized) {
      _reverseSelectedOp = provider.reverseOperation;
      _reverseSelectedNum = provider.selectedNumber;
      _reverseInitialized = true;
    }

    return Card(
      color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: AppConstants.accentColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: AppConstants.accentColor,
                  size: 22.r,
                ),
                SizedBox(width: 8.w),
                Text(
                  'FORMULA VERIFICATION STEP',
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppConstants.accentColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              'Input Reverse Formula',
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Configure the reverse mathematical operation to retrieve original code: ${provider.userSelectedOption} ? ? = ${provider.sessionCode}',
              style: GoogleFonts.outfit(fontSize: 12.sp, color: Colors.grey),
            ),

            SizedBox(height: 20.h),

            Text(
              'Reverse Operator:',
              style: GoogleFonts.outfit(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _reverseSelectedOp == '+'
                          ? AppConstants.accentColor
                          : (isDarkMode
                                ? Colors.white.withOpacity(0.04)
                                : Colors.grey.withOpacity(0.1)),
                      foregroundColor: _reverseSelectedOp == '+'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    onPressed: () => setState(() => _reverseSelectedOp = '+'),
                    child: Text(
                      'Plus (+)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _reverseSelectedOp == '-'
                          ? AppConstants.accentColor
                          : (isDarkMode
                                ? Colors.white.withOpacity(0.04)
                                : Colors.grey.withOpacity(0.1)),
                      foregroundColor: _reverseSelectedOp == '-'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    onPressed: () => setState(() => _reverseSelectedOp = '-'),
                    child: Text(
                      'Minus (-)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 18.h),

            Text(
              'Reverse Offset Number:',
              style: GoogleFonts.outfit(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _reverseSelectedNum,
                  dropdownColor: isDarkMode
                      ? const Color(0xFF151B2C)
                      : Colors.white,
                  items: List.generate(10, (index) => index + 1)
                      .map(
                        (val) => DropdownMenuItem<int>(
                          value: val,
                          child: Text(
                            'Offset: $val',
                            style: GoogleFonts.outfit(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _reverseSelectedNum = val);
                    }
                  },
                ),
              ),
            ),

            SizedBox(height: 24.h),
            const Divider(),
            SizedBox(height: 14.h),

            Center(
              child: Text(
                '${provider.userSelectedOption} $_reverseSelectedOp $_reverseSelectedNum = ${provider.sessionCode}',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: AppConstants.accentColor,
                ),
              ),
            ),

            SizedBox(height: 24.h),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              onPressed: () async {
                final success = await provider.verifyReverseFormula(
                  selectedOp: _reverseSelectedOp,
                  selectedNum: _reverseSelectedNum,
                );

                if (success) {
                  _showSnackBar(
                    'Authentication Verified successfully!',
                    AppConstants.accentColor,
                    Icons.verified_rounded,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => DashboardScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } else {
                  _showSnackBar(
                    provider.errorMessage ??
                        'Verification Failed. Session reloaded.',
                    AppTheme.errorColor,
                    Icons.error_outline_rounded,
                  );
                }
              },
              child: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Apply Formula Verification',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestBlockedCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: const BoxDecoration(
              color: AppTheme.errorColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block_flipped,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Security tab authentication not available for guest users.',
            style: GoogleFonts.outfit(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
