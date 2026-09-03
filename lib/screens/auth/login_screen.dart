import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';
import '../common/role_routing.dart';

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
  bool _resetBusy = false;

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
      context.go(roleHome(authController.role));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authController.errorMessage ?? 'Login failed. Please try again.',
          ),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  Future<void> _forgotPassword() async {
    setState(() => _resetBusy = true);
    try {
      await AuthService().sendPasswordReset(_idCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent if the account exists.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _resetBusy = false);
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
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: SvgPicture.asset(
                      'assets/images/hayaat_logo.svg',
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hayaat',
                          style: AppText.display.copyWith(
                            color: c.text,
                            fontSize: 24,
                          ),
                        ),
                        TextSpan(
                          text: 'ID',
                          style: AppText.display.copyWith(
                            color: c.primary,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome back',
                style: AppText.display.copyWith(color: c.text, fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to your HayaatID account',
                style: AppText.body.copyWith(color: c.text2),
              ),
              const SizedBox(height: 22),
              _Segmented(
                isPatient: _isPatient,
                onChanged: (v) => setState(() => _isPatient = v),
              ),
              const SizedBox(height: 20),
              _FieldLabel('CNIC, Hayaat ID, email, or phone'),
              const SizedBox(height: 8),
              _Field(
                controller: _idCtrl,
                icon: Icons.badge_outlined,
                hint: '3520112345671',
                hasError: idEmpty,
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
                    style: AppText.caption.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_showError) ...[
                const SizedBox(height: 8),
                Text(
                  'Please enter your CNIC, Hayaat ID, email, or phone and password.',
                  style: AppText.caption.copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PressScale(
                  onTap: _resetBusy ? null : _forgotPassword,
                  semanticLabel: 'Forgot password',
                  child: Text(
                    _resetBusy ? 'Sending reset…' : 'Forgot password?',
                    style: AppText.caption.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Consumer<AuthController>(
                builder: (context, auth, child) {
                  return GradientButton(
                    label: _isPatient
                        ? 'Sign in as Patient'
                        : 'Sign in as Staff',
                    loading: auth.isLoading,
                    onPressed: _signIn,
                  );
                },
              ),
              const SizedBox(height: 18),
              _InfoBanner(
                text: _isPatient
                    ? 'Sign in with your 13-digit CNIC, your 16-digit Hayaat ID, email, or phone.'
                    : 'Staff sign in with their CNIC, Hayaat ID, approved email, or Employee ID.',
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'New here? ',
                      style: AppText.body.copyWith(color: c.text2),
                    ),
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
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.hasError = false,
    this.trailing,
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
        border: Border.all(color: hasError ? c.danger : c.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.text3, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
          _segment(context, 'Staff', !isPatient, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
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
