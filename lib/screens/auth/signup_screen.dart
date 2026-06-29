import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _consent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cnicCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _enabled =>
      _nameCtrl.text.trim().isNotEmpty &&
      _cnicCtrl.text.trim().length == 13 &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _pwCtrl.text.isNotEmpty &&
      _consent;

  Future<void> _signUp() async {
    if (_pwCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Passwords do not match.'),
          backgroundColor: Colors.red[800],
        ),
      );
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.signUp(
      name: _nameCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim(),
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : '${_phoneCtrl.text.trim()}@hayaatid.com',
      password: _pwCtrl.text,
      phone: _phoneCtrl.text.trim(),
    );

    if (success && mounted) {
      context.push('/otp');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authController.errorMessage ?? 'Registration failed. Please try again.'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _BackButton(onTap: () => context.pop()),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create account',
                        style: AppText.heading.copyWith(
                          color: c.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quick & secure sign-up',
                        style: AppText.caption.copyWith(color: c.text2),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _Label(text: 'Full name'),
              const SizedBox(height: 8),
              _Field(
                controller: _nameCtrl,
                hint: 'e.g. Ayesha Khan',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _Label(text: 'CNIC'),
              const SizedBox(height: 8),
              _Field(
                controller: _cnicCtrl,
                hint: '13 digits, no dashes',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _Label(text: 'Email', muted: '(optional)'),
              const SizedBox(height: 8),
              _Field(
                controller: _emailCtrl,
                hint: 'you@email.com',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _Label(text: 'Phone'),
              const SizedBox(height: 8),
              _Field(
                controller: _phoneCtrl,
                hint: '3XX XXXXXXX',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefix: '+92',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(text: 'Password'),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _pwCtrl,
                          hint: '••••••',
                          obscure: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(text: 'Confirm'),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _confirmCtrl,
                          hint: '••••••',
                          obscure: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ConsentRow(
                value: _consent,
                onTap: () => setState(() => _consent = !_consent),
              ),
              const SizedBox(height: 22),
              Consumer<AuthController>(
                builder: (context, auth, child) {
                  return GradientButton(
                    label: 'Continue',
                    enabled: _enabled,
                    loading: auth.isLoading,
                    onPressed: _enabled ? _signUp : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? muted;
  const _Label({required this.text, this.muted});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Text(
          text,
          style: AppText.caption
              .copyWith(color: c.text2, fontWeight: FontWeight.w700),
        ),
        if (muted != null) ...[
          const SizedBox(width: 6),
          Text(
            muted!,
            style: AppText.caption.copyWith(color: c.text3),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final String? prefix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.prefix,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(prefix!, style: AppText.mono.copyWith(color: c.text2)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              style: AppText.body.copyWith(color: c.text),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.body.copyWith(color: c.text3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  const _ConsentRow({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'I agree to the Terms',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value ? c.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: value
                  ? null
                  : Border.all(color: c.text3, width: 2),
            ),
            child: value
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppText.caption.copyWith(color: c.text2, height: 1.45),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms',
                    style: AppText.caption.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' and consent to my medical records being stored securely.',
                  ),
                ],
              ),
            ),
          ),
        ],
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
