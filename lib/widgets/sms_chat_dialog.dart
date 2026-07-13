import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:enquiry_app/services/storage_service.dart';
import 'package:enquiry_app/providers/riverpod_providers.dart';
import 'package:enquiry_app/chartfile/chat_screen.dart';
import 'package:enquiry_app/screens/login_screen.dart';

class SmsChatDialog extends ConsumerStatefulWidget {
  final String phone;
  final String module;
  final int referenceId;
  final String userName;

  const SmsChatDialog({
    super.key,
    required this.phone,
    required this.module,
    required this.referenceId,
    required this.userName,
  });

  @override
  ConsumerState<SmsChatDialog> createState() => _SmsChatDialogState();
}

class _SmsChatDialogState extends ConsumerState<SmsChatDialog> {
  final TextEditingController _smsController = TextEditingController();
  int _charCount = 0;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _smsController.addListener(() {
      final len = _smsController.text.length;
      setState(() {
        _charCount = len;
      });
      if (len >= 100) {
        if (!_dialogShown) {
          _dialogShown = true;
          _showLimitReachedPopup();
        }
      } else {
        _dialogShown = false;
      }
    });
  }

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _showLimitReachedPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "SMS Character Limit Reached",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          content: const Text(
            "You have reached the maximum SMS limit (100 characters). To continue typing a longer message, please switch to Chat.",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the popup
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the popup
                _handleContinueInChat(_smsController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B5BDB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Continue in Chat",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendSms(String text) async {
    final Uri uri = Uri(
      scheme: 'sms',
      path: widget.phone,
      queryParameters: {'body': text},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch SMS app")),
          );
        }
      }
    }
  }

  Future<void> _handleContinueInChat(String messageText) async {
    final storageService = ref.read(storageServiceProvider);
    Navigator.pop(context); // Close parent SmsChatDialog

    if (storageService.isLoggedIn) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            module: widget.module,
            referenceId: widget.referenceId,
            userName: widget.userName,
            initialMessage: messageText,
          ),
        ),
      );
    } else {
      // Launch external url
      final Uri loginUri = Uri.parse("https://user.jobes24x7.com/");
      try {
        await launchUrl(loginUri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!mounted) return;
      // Navigate to local LoginScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            redirectModule: widget.module,
            redirectReferenceId: widget.referenceId,
            redirectUserName: widget.userName,
            redirectInitialMessage: messageText,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.sms,
                  color: Color(0xFF3B5BDB),
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  "Send Message",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _smsController,
              maxLines: 4,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: "Type your message here...",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                counterText: "", // Hide default counter
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF3B5BDB),
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "$_charCount / 100",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _charCount >= 100 ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _charCount == 0
                      ? null
                      : () {
                          Navigator.pop(context);
                          _sendSms(_smsController.text);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5BDB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Send SMS",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
