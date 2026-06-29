import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Doctor registration (P-FR-002 / UC-D001). Submits to /auth/register/doctor;
/// the account is created PENDING and cannot log in until an admin approves it.
class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  final _service = AuthService();
  final _name = TextEditingController();
  final _cnic = TextEditingController();
  final _phone = TextEditingController();
  final _pmdc = TextEditingController();
  final _spec = TextEditingController();
  final _pw = TextEditingController();
  bool _mbbs = true;
  bool _fcps = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    _phone.dispose();
    _pmdc.dispose();
    _spec.dispose();
    _pw.dispose();
    super.dispose();
  }

  bool get _enabled =>
      _name.text.trim().isNotEmpty &&
      _cnic.text.trim().length == 13 &&
      _pmdc.text.trim().isNotEmpty &&
      _spec.text.trim().isNotEmpty &&
      _pw.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final message = await _service.registerDoctor(
        cnic: _cnic.text.trim(),
        fullName: _name.text.trim(),
        password: _pw.text,
        pmdcNumber: _pmdc.text.trim(),
        specialization: _spec.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        mbbs: _mbbs,
        fcps: _fcps,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(Icons.verified_outlined, color: context.c.primary, size: 36),
          title: const Text('Application submitted'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/login');
              },
              child: const Text('Back to login'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[800]));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Register as a doctor', style: AppText.heading.copyWith(color: c.text, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.sky, borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                Icon(Icons.info_outline, color: c.skyFg, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Your account is reviewed by an administrator before you can log in. PMDC details are verified during review.',
                  style: AppText.caption.copyWith(color: c.text2, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            _field('Full name', _name),
            _field('CNIC (13 digits)', _cnic, keyboard: TextInputType.number, formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ]),
            _field('Phone', _phone, keyboard: TextInputType.phone),
            _field('PMDC number', _pmdc),
            _field('Primary specialization', _spec),
            _field('Password', _pw, obscure: true),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _mbbs,
              activeColor: c.primary,
              onChanged: (v) => setState(() => _mbbs = v ?? false),
              title: Text('MBBS', style: TextStyle(color: c.text)),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _fcps,
              activeColor: c.primary,
              onChanged: (v) => setState(() => _fcps = v ?? false),
              title: Text('FCPS', style: TextStyle(color: c.text)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_enabled && !_busy) ? _submit : null,
                style: FilledButton.styleFrom(backgroundColor: c.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit application', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool obscure = false, TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption.copyWith(color: c.text2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          inputFormatters: formatters,
          onChanged: (_) => setState(() {}),
          style: AppText.body.copyWith(color: c.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
          ),
        ),
      ]),
    );
  }
}
