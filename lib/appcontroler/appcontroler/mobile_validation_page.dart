import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mobile_validation_service.dart';
import 'package:enquiry_app/screens/dashboard_screen.dart';

class MobileValidationPage extends StatefulWidget {
  const MobileValidationPage({super.key});

  @override
  State<MobileValidationPage> createState() => _MobileValidationPageState();
}

class _MobileValidationPageState extends State<MobileValidationPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startValidation();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startValidation() async {
    setState(() {
      _isRetrying = false;
    });

    print("Triggering automatic Mobile Validation API...");
    final success =
        await MobileValidationService.runAutomaticMobileValidation();

    if (success) {
      print("Mobile Validation succeeded! Navigating to Dashboard.");
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('verification_completed', true);

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      print("Mobile Validation failed.");
      if (!mounted) return;
      _showFailureDialog();
    }
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 10),
                Text(
                  "Validation Failed",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              "Mobile validation secure handshake could not be completed. Please check your network connection and try again.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isRetrying = true;
                  });
                  _startValidation();
                },
                child: const Text(
                  "Retry Verification",
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.deepPurple.withOpacity(0.12),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.phonelink_lock,
                              size: 44,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  const Text(
                    "Mobile Validation",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Performing secure backend handshake verification. This happens automatically, please do not close the app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(flex: 2),

                  Column(
                    children: [
                      const SizedBox(
                        width: 48,
                        child: LinearProgressIndicator(
                          color: Colors.deepPurple,
                          backgroundColor: Color(0xFFEFF0F6),
                          minHeight: 3.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isRetrying
                            ? "Retrying Secure Connection..."
                            : "Securing Connection...",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
