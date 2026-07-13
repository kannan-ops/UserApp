import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityTapWidget extends StatefulWidget {
  final VoidCallback onVerificationSuccess;

  const SecurityTapWidget({super.key, required this.onVerificationSuccess});

  @override
  State<SecurityTapWidget> createState() => _SecurityTapWidgetState();
}

class _SecurityTapWidgetState extends State<SecurityTapWidget> {
  final Random _random = Random();
  late int _baseNumber;
  late int _selectedAdder;
  late int _correctAnswer;
  List<int> _options = [];
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _resetVerification();
  }

  void _resetVerification() {
    _baseNumber = _random.nextInt(80) + 15;
    _selectedAdder = _random.nextInt(9) + 1;
    _generateOptions();
  }

  void _generateOptions() {
    _correctAnswer = _baseNumber + _selectedAdder;

    print("SECURITY QUESTION: $_baseNumber + $_selectedAdder");
    print("CORRECT ANSWER: $_correctAnswer");

    Set<int> uniqueOptions = {_correctAnswer};

    while (uniqueOptions.length < 5) {
      int offset = _random.nextInt(30) - 15;
      if (offset == 0) continue;
      int wrongVal = _correctAnswer + offset;
      if (wrongVal > 0 && wrongVal != _correctAnswer) {
        uniqueOptions.add(wrongVal);
      }
    }

    _options = uniqueOptions.toList()..shuffle();
  }

  void _onAdderPressed(int val) {
    if (_isVerified) return;
    setState(() {
      _selectedAdder = val;
      _generateOptions();
    });
  }

  Future<void> _onOptionSelected(int selectedVal) async {
    if (_isVerified) return;

    print("USER SELECTED: $selectedVal");

    if (selectedVal == _correctAnswer) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_verified', true);

      setState(() {
        _isVerified = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Security Verification Success"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      widget.onVerificationSuccess();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text("Invalid Verification"),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      setState(() {
        _resetVerification();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 40,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          const Text(
            "Tap correct result to continue",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$_baseNumber",
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "+ $_selectedAdder",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepPurple.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "=  ?",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                "SELECT ADDER NUMBER",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(9, (index) {
              final val = index + 1;
              final isSelected = _selectedAdder == val;
              return SizedBox(
                width: 60,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerified ? null : () => _onAdderPressed(val),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.deepPurple
                        : Colors.grey.shade100,
                    foregroundColor: isSelected ? Colors.white : Colors.black87,
                    elevation: isSelected ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    "+$val",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                "TAP CORRECT OPTION RESULT",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _options.map((opt) {
              return SizedBox(
                width: 90,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isVerified ? null : () => _onOptionSelected(opt),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(
                      color: Colors.deepPurple,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: _isVerified && opt == _correctAnswer
                        ? Colors.green.withOpacity(0.1)
                        : Colors.white,
                  ),
                  child: Text(
                    "$opt",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
