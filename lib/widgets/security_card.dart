import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enquiry_app/models/security_setting.dart';

class SecurityCard extends StatelessWidget {
  final SecuritySetting setting;
  final ValueChanged<bool> onChanged;
  final bool isPending;
  final VoidCallback? onConfigure;

  const SecurityCard({
    super.key,
    required this.setting,
    required this.onChanged,
    this.isPending = false,
    this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: isDarkMode ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                setting.icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24.w,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    setting.title,
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    setting.subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  if (setting.isEnabled) ...[
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: onConfigure,
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_suggest_outlined,
                            size: 12.w,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "Configure Option",
                            style: GoogleFonts.outfit(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            isPending
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : Switch(
                    value: setting.isEnabled,
                    onChanged: onChanged,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
          ],
        ),
      ),
    );
  }
}
