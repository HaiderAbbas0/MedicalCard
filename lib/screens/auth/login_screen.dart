import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isPatient = true;
  bool _obscure = true;
  bool _showError = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final ok = _idCtrl.text.trim().isNotEmpty && _pwCtrl.text.isNotEmpty;
    if (!ok) {
      setState(() => _showError = true);
      return;
    }
    final authController = context.read<AuthController>();
    final success = await authController.login(
      _idCtrl.text.trim(),
      _pwCtrl.text,
    );
    if (success && mounted) {
      context.go('/dashboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authController.errorMessage ?? 'Login failed. Please try again.'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final idEmpty = _showError && _idCtrl.text.trim().isEmpty;
    final pwEmpty = _showError && _pwCtrl.text.isEmpty;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: brandGradient(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.button,
                ),
                child: const _Cross(size: 26, color: Colors.white),
              ),
              const SizedBox(height: 22),
              Text('Welcome back',
                  style: AppText.display.copyWith(color: c.text, fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                'Sign in to your Sehat ID account',
                style: AppText.body.copyWith(color: c.text2),
              ),
              const SizedBox(height: 22),
              _Segmented(
                isPatient: _isPatient,
                onChanged: (v) => setState(() => _isPatient = v),
              ),
              const SizedBox(height: 20),
              _FieldLabel('Email or Phone'),
              const SizedBox(height: 8),
              _Field(
                controller: _idCtrl,
                icon: Icons.mail_outline_rounded,
                hint: 'you@email.com  ·  03XX XXXXXXX',
                hasError: idEmpty,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_showError) setState(() => _showError = false);
                },
              ),
              const SizedBox(height: 16),
              _FieldLabel('Password'),
              const SizedBox(height: 8),
              _Field(
                controller: _pwCtrl,
                icon: Icons.lock_outline_rounded,
                hint: '••••••••',
                obscure: _obscure,
                hasError: pwEmpty,
                onChanged: (_) {
                  if (_showError) setState(() => _showError = false);
                },
                trailing: PressScale(
                  onTap: () => setState(() => _obscure = !_obscure),
                  semanticLabel: _obscure ? 'Show password' : 'Hide password',
                  child: Text(
                    _obscure ? 'Show' : 'Hide',
                    style: AppText.caption
                        .copyWith(color: c.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_showError) ...[
                const SizedBox(height: 8),
                Text(
                  'Please enter your email/phone and password.',
                  style: AppText.caption.copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PressScale(
                  onTap: () {},
                  semanticLabel: 'Forgot password',
                  child: Text(
                    'Forgot password?',
                    style: AppText.caption
                        .copyWith(color: c.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Consumer<AuthController>(
                builder: (context, auth, child) {
                  return GradientButton(
                    label: _isPatient ? 'Sign in as Patient' : 'Sign in as Doctor',
                    loading: auth.isLoading,
                    onPressed: _signIn,
                  );
                },
              ),
              const SizedBox(height: 18),
              _InfoBanner(
                text: _isPatient
                    ? 'Sign in with the email or phone you registered with.'
                    : 'Doctors are verified against the PMDC registry before access.',
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('New here? ',
                        style: AppText.body.copyWith(color: c.text2)),
                    PressScale(
                      onTap: () => context.push('/signup'),
                      semanticLabel: 'Create account',
                      child: Text(
                        'Create account',
                        style: AppText.bodyStrong.copyWith(color: c.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.caption.copyWith(
        color: context.c.text2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final bool hasError;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.hasError = false,
    this.trailing,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? c.danger : c.primary,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.text3, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
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
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final bool isPatient;
  final ValueChanged<bool> onChanged;

  const _Segmented({required this.isPatient, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _segment(context, 'Patient', isPatient, () => onChanged(true)),
          _segment(context, 'Doctor', !isPatient, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    final c = context.c;
    return Expanded(
      child: PressScale(
        onTap: onTap,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? brandGradient(context) : null,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected ? AppShadows.button : null,
          ),
          child: Text(
            label,
            style: AppText.bodyStrong.copyWith(
              color: selected ? Colors.white : c.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.sky,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: c.skyFg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(color: c.text2, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// White / colored medical cross built from two rounded rectangles.
class _Cross extends StatelessWidget {
  final double size;
  final Color color;
  const _Cross({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.30;
    final radius = BorderRadius.circular(size * 0.12);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: bar,
            height: size,
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
          Container(
            width: size,
            height: bar,
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ],
      ),
    );
  }
}
