import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PinPad extends StatefulWidget {
  final Function(String) onPinCompleted;
  final VoidCallback? onBiometricPressed;
  final bool showBiometricButton;
  final String errorMessage;

  const PinPad({
    super.key,
    required this.onPinCompleted,
    this.onBiometricPressed,
    this.showBiometricButton = false,
    this.errorMessage = '',
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 15.0,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage.isNotEmpty &&
        oldWidget.errorMessage != widget.errorMessage) {
      _shakeController.forward(from: 0.0).then((_) {
        _shakeController.reverse();
        setState(() {
          _enteredPin = '';
        });
      });
    }
  }

  void _onNumberPress(int number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number.toString();
      });

      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () {
          widget.onPinCompleted(_enteredPin);
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Widget _buildDot(int index) {
    bool isFilled = index < _enteredPin.length;
    Color color = widget.errorMessage.isNotEmpty
        ? Colors.redAccent
        : Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: isFilled ? 20.w : 14.w,
      height: 14.h,
      decoration: BoxDecoration(
        color: isFilled ? color : Colors.transparent,
        border: Border.all(
          color: isFilled
              ? color
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          width: 2,
        ),
        shape: BoxShape.circle,
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildKeypadButton(dynamic content, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Container(
          width: 72.w,
          height: 72.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.03),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: content is Widget
              ? content
              : Text(
                  content.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _shakeAnimation.value * (1.0 - _shakeController.value),
                  0,
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => _buildDot(index)),
            ),
          ),

          if (widget.errorMessage.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(
              widget.errorMessage,
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          SizedBox(height: 48.h),

          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKeypadButton(1, () => _onNumberPress(1)),
                  _buildKeypadButton(2, () => _onNumberPress(2)),
                  _buildKeypadButton(3, () => _onNumberPress(3)),
                ],
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKeypadButton(4, () => _onNumberPress(4)),
                  _buildKeypadButton(5, () => _onNumberPress(5)),
                  _buildKeypadButton(6, () => _onNumberPress(6)),
                ],
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKeypadButton(7, () => _onNumberPress(7)),
                  _buildKeypadButton(8, () => _onNumberPress(8)),
                  _buildKeypadButton(9, () => _onNumberPress(9)),
                ],
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  widget.showBiometricButton &&
                          widget.onBiometricPressed != null
                      ? _buildKeypadButton(
                          Icon(
                            Icons.fingerprint_rounded,
                            size: 32.w,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          widget.onBiometricPressed!,
                        )
                      : SizedBox(width: 72.w, height: 72.w),

                  _buildKeypadButton(0, () => _onNumberPress(0)),

                  _buildKeypadButton(
                    Icon(
                      Icons.backspace_outlined,
                      size: 24.w,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    _onBackspace,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
