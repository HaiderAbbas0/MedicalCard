import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/compliance_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/otp_field.dart';
import '../../widgets/common/press_scale.dart';

class OtpScreen extends StatefulWidget {
  /// Pending sign-up data passed from the signup screen.
  /// When null, the screen is used standalone (e.g. password-reset flow).
  final Map<String, dynamic>? pendingSignup;

  const OtpScreen({super.key, this.pendingSignup});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _key = GlobalKey<OtpFieldState>();
  String _code = '';
  bool _error = false;
  bool _busy = false;
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

  // ── Back-press intercept ─────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel sign-up?'),
        content: const Text(
          'Are you sure you want to go back? Your progress will be lost and sign-up will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel sign-up'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _timer?.cancel();
      return true;
    }
    return false;
  }

  // ── OTP verification & deferred account creation ────────────────────────────
  Future<void> _verify() async {
    // Development OTP gate. Replace with the configured SMS provider before release.
    if (_code != '11111') {
      _key.currentState?.shake();
      setState(() => _error = true);
      return;
    }

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // If this screen was reached from the signup form, create the account now.
      if (widget.pendingSignup != null) {
        final data = widget.pendingSignup!;
        final ok = await context.read<AuthController>().signUp(
          name: data['name'] as String,
          email: data['email'] as String? ?? '',
          cnic: data['cnic'] as String,
          phone: data['phone'] as String,
          password: data['password'] as String,
          gender: data['gender'] as String?,
          dob: data['dob'] as String?,
          emergencyPhone: data['emergencyPhone'] as String?,
        );

        if (!mounted) return;

        if (!ok) {
          final errMsg =
              context.read<AuthController>().errorMessage ?? 'Sign up failed.';
          messenger.showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red[800]),
          );
          setState(() => _busy = false);
          return;
        }

        // The account exists now — record acceptance of the current Privacy
        // Policy + Terms (given via the sign-up consent). Best-effort: a failure
        // here must not block the user from reaching the app.
        try {
          await ComplianceService().recordSignupConsent();
        } catch (_) {
          /* non-blocking */
        }
      } else {
        // Standalone OTP (e.g. a login step): just complete the existing session.
        await context.read<AuthController>().completeLogin();
      }

      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red[800],
          ),
        );
        setState(() => _busy = false);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return PopScope(
      // Intercept hardware back button and in-app back navigation.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button also triggers the confirmation dialog.
                _BackButton(
                  onTap: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && context.mounted) context.pop();
                  },
                ),
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
                      const TextSpan(
                        text:
                            'Enter the 5-digit verification code sent to your phone.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                OtpField(
                  key: _key,
                  length: 5,
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
                Center(
                  child: _ResendLine(seconds: _seconds, onResend: _startTimer),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Verify & create account',
                  enabled: _code.length == 5 && !_busy,
                  loading: _busy,
                  onPressed: _code.length == 5 && !_busy ? _verify : null,
                ),
              ],
            ),
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
        'Didn\'t get it? Resend code',
        style: AppText.caption.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w700,
        ),
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
