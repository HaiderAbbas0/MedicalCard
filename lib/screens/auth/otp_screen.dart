import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/otp_field.dart';
import '../../widgets/common/press_scale.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _key = GlobalKey<OtpFieldState>();
  String _code = '';
  bool _error = false;
  int _seconds = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    final auth = context.read<AuthController>();
    if (auth.verifyOtp(_code)) {
      await auth.completeLogin();
      if (mounted) context.go('/dashboard');
    } else {
      _key.currentState?.shake();
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackButton(onTap: () => context.pop()),
              const SizedBox(height: 28),
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.mint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.sms_outlined, color: c.mintFg, size: 30),
              ),
              const SizedBox(height: 22),
              Text(
                'Verify your number',
                style: AppText.display.copyWith(
                  color: c.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: AppText.body.copyWith(color: c.text2),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: '+92 3•• ••• ••21',
                      style: AppText.bodyStrong.copyWith(color: c.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              OtpField(
                key: _key,
                onChanged: (v) => setState(() {
                  _code = v;
                  _error = false;
                }),
              ),
              if (_error) ...[
                const SizedBox(height: 14),
                Text(
                  'Incorrect code. Please try again.',
                  style: AppText.caption.copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: 24),
              Center(child: _ResendLine(seconds: _seconds, onResend: _startTimer)),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Verify & continue',
                enabled: _code.length == 6,
                onPressed: _code.length == 6 ? _verify : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendLine extends StatelessWidget {
  final int seconds;
  final VoidCallback onResend;
  const _ResendLine({required this.seconds, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (seconds > 0) {
      final ss = seconds.toString().padLeft(2, '0');
      return Text(
        'Resend code in 0:$ss',
        style: AppText.caption.copyWith(color: c.text2),
      );
    }
    return PressScale(
      onTap: onResend,
      semanticLabel: 'Resend code',
      child: Text(
        'Didn’t get it? Resend code',
        style: AppText.caption
            .copyWith(color: c.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Back',
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Icon(Icons.chevron_left_rounded, color: c.text, size: 24),
      ),
    );
  }
}
