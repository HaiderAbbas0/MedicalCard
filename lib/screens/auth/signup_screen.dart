import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

/// Unified create-account screen — same visual language as the login screen.
/// Account type (Patient / Staff) is chosen first; Staff = doctor self-register.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isPatient = true; // false = staff (doctor)
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emergency = TextEditingController();
  final _pw = TextEditingController();
  final _pmdc = TextEditingController();
  final _spec = TextEditingController();
  String _gender = 'male';
  DateTime? _dob;
  bool _consent = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _emergency, _pw, _pmdc, _spec]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _enabled {
    final base = _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty && _pw.text.isNotEmpty && _consent;
    if (_isPatient) return base && _dob != null;
    return base && _pmdc.text.trim().isNotEmpty && _spec.text.trim().isNotEmpty;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isPatient) {
        final ok = await context.read<AuthController>().signUp(
              name: _name.text.trim(),
              email: _email.text.trim(),
              phone: _phone.text.trim(),
              password: _pw.text,
              gender: _gender,
              dob: _dob?.toIso8601String().substring(0, 10),
              emergencyPhone: _emergency.text.trim(),
            );
        if (!mounted) return;
        if (ok) {
          context.push('/otp');
        } else {
          messenger.showSnackBar(SnackBar(
            content: Text(context.read<AuthController>().errorMessage ?? 'Sign up failed.'),
            backgroundColor: Colors.red[800]));
          setState(() => _busy = false);
        }
      } else {
        final msg = await AuthService().registerDoctor(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          password: _pw.text,
          pmdcNumber: _pmdc.text.trim(),
          specialization: _spec.text.trim(),
          gender: _gender,
          dob: _dob?.toIso8601String().substring(0, 10),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(Icons.verified_outlined, color: context.c.primary, size: 36),
            title: const Text('Application submitted'),
            content: Text(msg),
            actions: [FilledButton(onPressed: () { Navigator.pop(context); context.go('/login'); }, child: const Text('Back to login'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[800]));
        setState(() => _busy = false);
      }
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
              Row(children: [
                _BackButton(onTap: () => context.pop()),
                const Spacer(),
                Container(
                  width: 48, height: 48, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border), boxShadow: AppShadows.card,
                  ),
                  child: SvgPicture.asset('assets/images/hayaat_logo.svg', width: 30, height: 30),
                ),
              ]),
              const SizedBox(height: 18),
              Text('Create account', style: AppText.display.copyWith(color: c.text, fontSize: 26)),
              const SizedBox(height: 6),
              Text('Who are you?', style: AppText.body.copyWith(color: c.text2)),
              const SizedBox(height: 16),
              _Segmented(isPatient: _isPatient, onChanged: (v) => setState(() => _isPatient = v)),
              const SizedBox(height: 20),

              _label('Full name'),
              _field(_name, _isPatient ? 'e.g. Ayesha Khan' : 'e.g. Dr. Imran Yousuf'),
              const SizedBox(height: 14),

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Gender'),
                  _genderField(),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Date of Birth'),
                  _dobField(),
                ])),
              ]),
              const SizedBox(height: 14),

              if (!_isPatient) ...[
                _label('PMDC number'),
                _field(_pmdc, 'e.g. PMDC-12345-C'),
                const SizedBox(height: 14),
                _label('Specialization'),
                _field(_spec, 'e.g. Cardiology'),
                const SizedBox(height: 14),
              ],

              _label('Email (optional)'),
              _field(_email, 'you@email.com', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),

              _label('Phone number'),
              _field(_phone, '03XX XXXXXXX', keyboard: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 14),

              if (_isPatient) ...[
                _label('Emergency contact number'),
                _field(_emergency, '03XX XXXXXXX', keyboard: TextInputType.phone,
                    formatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 14),
              ],

              _label('Password'),
              _field(_pw, 'Create a password', obscure: true),
              const SizedBox(height: 18),

              _ConsentRow(value: _consent, onTap: () => setState(() => _consent = !_consent)),
              const SizedBox(height: 22),
              GradientButton(
                label: _isPatient ? 'Create account' : 'Submit application',
                enabled: _enabled,
                loading: _busy,
                onPressed: _enabled ? _submit : null,
              ),
              const SizedBox(height: 18),
              Center(
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('Already have an account? ', style: AppText.body.copyWith(color: c.text2)),
                  PressScale(
                    onTap: () => context.go('/login'),
                    semanticLabel: 'Sign in',
                    child: Text('Sign in', style: AppText.bodyStrong.copyWith(color: c.primary)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: AppText.caption.copyWith(color: context.c.text2, fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {bool obscure = false, TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    final c = context.c;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Center(
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          inputFormatters: formatters,
          onChanged: (_) => setState(() {}),
          style: AppText.body.copyWith(color: c.text),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: AppText.body.copyWith(color: c.text3),
          ),
        ),
      ),
    );
  }

  Widget _genderField() {
    final c = context.c;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender,
          isExpanded: true,
          style: AppText.body.copyWith(color: c.text),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _gender = v ?? 'male'),
        ),
      ),
    );
  }

  Widget _dobField() {
    final c = context.c;
    return InkWell(
      onTap: _pickDob,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Text(
          _dob == null ? 'Select' : _dob!.toIso8601String().substring(0, 10),
          style: AppText.body.copyWith(color: _dob == null ? c.text3 : c.text),
        ),
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
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(children: [
        _seg(context, 'Patient', isPatient, () => onChanged(true)),
        _seg(context, 'Staff', !isPatient, () => onChanged(false)),
      ]),
    );
  }

  Widget _seg(BuildContext context, String label, bool selected, VoidCallback onTap) {
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
          child: Text(label, style: AppText.bodyStrong.copyWith(color: selected ? Colors.white : c.text2)),
        ),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: value ? null : Border.all(color: c.text3, width: 2),
          ),
          child: value ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(
            style: AppText.caption.copyWith(color: c.text2, height: 1.45),
            children: [
              const TextSpan(text: 'I agree to the '),
              TextSpan(text: 'Terms', style: AppText.caption.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
              const TextSpan(text: ' and consent to my medical records being stored securely.'),
            ],
          )),
        ),
      ]),
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
        width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Icon(Icons.chevron_left_rounded, color: c.text, size: 24),
      ),
    );
  }
}
