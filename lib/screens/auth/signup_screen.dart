import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

/// Patient-only create-account screen. Validates all inputs locally and checks
/// Supabase for an existing phone number before navigating to the OTP screen.
/// Actual account creation is deferred until after OTP verification.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emergency = TextEditingController();
  final _pw = TextEditingController();
  String _gender = 'male';
  DateTime? _dob;
  bool _consent = false;
  bool _busy = false;

  // Validation error messages (shown inline)
  String? _phoneError;
  String? _emailError;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _emergency, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  /// Phone must be exactly 11 digits (Pakistani mobile format).
  String? _validatePhone(String val) {
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // required check handled by _enabled
    if (digits.length != 11) return 'Phone number must be exactly 11 digits.';
    return null;
  }

  /// Email is optional but must be a @gmail.com address when provided.
  String? _validateEmail(String val) {
    if (val.trim().isEmpty) return null;
    final trimmed = val.trim().toLowerCase();
    if (!trimmed.endsWith('@gmail.com')) {
      return 'Only @gmail.com addresses are accepted.';
    }
    return null;
  }

  bool get _enabled {
    final phoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final phoneOk = phoneDigits.length == 11;
    final emailOk = _validateEmail(_email.text) == null;
    return _name.text.trim().isNotEmpty &&
        phoneOk &&
        emailOk &&
        _pw.text.isNotEmpty &&
        _dob != null &&
        _consent;
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

  // ── Submit: validate → check Supabase → navigate to OTP ────────────────────
  Future<void> _submit() async {
    // Run validators
    final phoneErr = _validatePhone(_phone.text);
    final emailErr = _validateEmail(_email.text);
    setState(() {
      _phoneError = phoneErr;
      _emailError = emailErr;
    });
    if (phoneErr != null || emailErr != null) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Check Supabase for an existing user with the same phone number.
      final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
      final existing = await db
          .from('profiles')
          .select('id')
          .eq('phone_primary', phone)
          .maybeSingle();

      if (!mounted) return;

      if (existing != null) {
        messenger.showSnackBar(SnackBar(
          content: const Text('A user with this phone number already exists.'),
          backgroundColor: Colors.red[800],
        ));
        setState(() => _busy = false);
        return;
      }

      // Bundle form data and hand off to OTP screen — no Supabase write yet.
      final pendingData = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': phone,
        'password': _pw.text,
        'gender': _gender,
        'dob': _dob?.toIso8601String().substring(0, 10),
        'emergencyPhone': _emergency.text.trim().isEmpty
            ? null
            : _emergency.text.replaceAll(RegExp(r'\D'), ''),
      };

      if (mounted) context.push('/otp', extra: pendingData);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red[800],
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
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
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: SvgPicture.asset('assets/images/hayaat_logo.svg',
                      width: 30, height: 30),
                ),
              ]),
              const SizedBox(height: 18),
              Text('Create account',
                  style:
                      AppText.display.copyWith(color: c.text, fontSize: 26)),
              const SizedBox(height: 6),
              Text('Register as a new patient.',
                  style: AppText.body.copyWith(color: c.text2)),
              const SizedBox(height: 20),

              _label('Full name'),
              _field(_name, 'e.g. Ayesha Khan'),
              const SizedBox(height: 14),

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('Gender'),
                      _genderField(),
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('Date of Birth'),
                      _dobField(),
                    ])),
              ]),
              const SizedBox(height: 14),

              _label('Email (Gmail only, optional)'),
              _field(_email, 'you@gmail.com',
                  keyboard: TextInputType.emailAddress),
              if (_emailError != null) ...[
                const SizedBox(height: 6),
                Text(_emailError!,
                    style: AppText.caption.copyWith(color: c.danger)),
              ],
              const SizedBox(height: 14),

              _label('Phone number'),
              _field(_phone, '03XXXXXXXXX',
                  keyboard: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 11),
              if (_phoneError != null) ...[
                const SizedBox(height: 6),
                Text(_phoneError!,
                    style: AppText.caption.copyWith(color: c.danger)),
              ],
              const SizedBox(height: 14),

              _label('Emergency contact number (optional)'),
              _field(_emergency, '03XXXXXXXXX',
                  keyboard: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 11),
              const SizedBox(height: 14),

              _label('Password'),
              _field(_pw, 'Create a password', obscure: true),
              const SizedBox(height: 18),

              _ConsentRow(
                  value: _consent,
                  onTap: () => setState(() => _consent = !_consent)),
              const SizedBox(height: 22),

              GradientButton(
                label: 'Continue to verification',
                enabled: _enabled,
                loading: _busy,
                onPressed: _enabled ? _submit : null,
              ),
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: AppText.body.copyWith(color: c.text2)),
                      PressScale(
                        onTap: () => context.go('/login'),
                        semanticLabel: 'Sign in',
                        child: Text('Sign in',
                            style: AppText.bodyStrong
                                .copyWith(color: c.primary)),
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
        child: Text(t,
            style: AppText.caption
                .copyWith(color: context.c.text2, fontWeight: FontWeight.w700)),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int? maxLength,
  }) {
    final c = context.c;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border)),
      child: Center(
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          inputFormatters: [
            ...?formatters,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          onChanged: (_) => setState(() {
            _phoneError = null;
            _emailError = null;
          }),
          style: AppText.body.copyWith(color: c.text),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: AppText.body.copyWith(color: c.text3),
            counterText: '',
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
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border)),
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
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border)),
        child: Text(
          _dob == null ? 'Select' : _dob!.toIso8601String().substring(0, 10),
          style:
              AppText.body.copyWith(color: _dob == null ? c.text3 : c.text),
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
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: value ? null : Border.all(color: c.text3, width: 2),
          ),
          child: value
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(
            style: AppText.caption.copyWith(color: c.text2, height: 1.45),
            children: [
              const TextSpan(text: 'I agree to the '),
              TextSpan(
                  text: 'Terms',
                  style: AppText.caption.copyWith(
                      color: c.primary, fontWeight: FontWeight.w800)),
              const TextSpan(
                  text:
                      ' and consent to my medical records being stored securely.'),
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
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border)),
        child: Icon(Icons.chevron_left_rounded, color: c.text, size: 24),
      ),
    );
  }
}
