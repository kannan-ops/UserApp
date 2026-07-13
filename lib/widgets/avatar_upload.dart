import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enquiry_app/utils/constants.dart';
import 'package:enquiry_app/theme/app_theme.dart';

class AvatarUpload extends StatelessWidget {
  final String currentPhotoUrl;
  final Function(String) onPhotoSelected;
  final bool isEditable;

  const AvatarUpload({
    super.key,
    required this.currentPhotoUrl,
    required this.onPhotoSelected,
    this.isEditable = true,
  });

  void _showAvatarSelector(BuildContext context) {
    if (!isEditable) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white30 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 24.h),

              Text(
                'Customize Avatar',
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Select one of our premium cybersecurity identities',
                style: GoogleFonts.outfit(
                  fontSize: 13.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppConstants.avatarOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final url = AppConstants.avatarOptions[index];
                  final isSelected = url == currentPhotoUrl;

                  return GestureDetector(
                    onTap: () {
                      onPhotoSelected(url);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12.w),
                              const Text(
                                'Profile avatar updated successfully!',
                              ),
                            ],
                          ),
                          backgroundColor: AppTheme.accentColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3.w,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: isDarkMode
                                  ? Colors.white10
                                  : Colors.black12,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.account_circle,
                              size: 60.r,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      context: context,
                      icon: Icons.camera_enhance_rounded,
                      label: 'Use Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _showMockToast(
                          context,
                          'Camera accessed (Mock Upload)',
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildActionTile(
                      context: context,
                      icon: Icons.photo_library_rounded,
                      label: 'From Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _showMockToast(
                          context,
                          'Photo Gallery opened (Mock Upload)',
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24.w,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMockToast(BuildContext context, String message) {
    final randomAvatar = AppConstants.avatarOptions[2];
    onPhotoSelected(randomAvatar);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: Colors.white),
            SizedBox(width: 12.w),
            Text('$message: Loaded new ID!'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppTheme.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

            GestureDetector(
              onTap: () => _showAvatarSelector(context),
              child: Container(
                width: 110.r,
                height: 110.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? const Color(0xFF151B2C) : Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: currentPhotoUrl.isNotEmpty
                          ? Image.network(
                              currentPhotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.person_rounded,
                                    size: 50.r,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 50.r,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            if (isEditable)
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _showAvatarSelector(context),
                  child: Container(
                    width: 34.r,
                    height: 34.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentColor,
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF0B0F19)
                            : Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 16.r,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
