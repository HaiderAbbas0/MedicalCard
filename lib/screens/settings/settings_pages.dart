import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../data/legal_text.dart';
import '../../services/compliance_service.dart';
import '../../services/supabase_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

/// Shared back-header scaffold for settings sub-pages.
class _SettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            Row(children: [
              PressScale(
                onTap: () => context.pop(),
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
                  child: Icon(Icons.chevron_left_rounded, size: 24, color: c.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: AppText.display.copyWith(fontSize: 22, color: c.text)),
              ),
            ]),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget _card(BuildContext context, {required List<Widget> children}) {
  final c = context.c;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

// ── Change password ───────────────────────────────────────────────────────────
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _newCtrl.text;
    if (pw.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (pw != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await db.auth.updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _SettingsScaffold(
      title: 'Change password',
      children: [
        Text('Choose a new password for your account.',
            style: AppText.body.copyWith(color: c.text2)),
        const SizedBox(height: 18),
        _field(context, 'New password', _newCtrl, obscure: _obscure),
        const SizedBox(height: 12),
        _field(context, 'Confirm new password', _confirmCtrl, obscure: _obscure),
        const SizedBox(height: 10),
        PressScale(
          onTap: () => setState(() => _obscure = !_obscure),
          semanticLabel: 'Toggle visibility',
          child: Row(children: [
            Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18, color: c.text3),
            const SizedBox(width: 8),
            Text(_obscure ? 'Show password' : 'Hide password',
                style: AppText.caption.copyWith(color: c.text2)),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: AppText.caption.copyWith(color: c.danger)),
        ],
        const SizedBox(height: 24),
        GradientButton(label: _busy ? 'Saving…' : 'Update password', onPressed: _busy ? null : _save),
      ],
    );
  }

  Widget _field(BuildContext context, String hint, TextEditingController ctrl, {bool obscure = false}) {
    final c = context.c;
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ── Login & security ──────────────────────────────────────────────────────────
class LoginSecurityScreen extends StatelessWidget {
  const LoginSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final lastSignIn = db.auth.currentUser?.lastSignInAt;
    return _SettingsScaffold(
      title: 'Login & security',
      children: [
        _card(context, children: [
          _row(context, 'Unique ID', user?.cardNumber ?? '—', mono: true),
          Divider(height: 22, color: c.border2),
          _row(context, 'Email', user?.email ?? '—'),
          Divider(height: 22, color: c.border2),
          _row(context, 'Phone', user?.phone ?? '—'),
          if (lastSignIn != null) ...[
            Divider(height: 22, color: c.border2),
            _row(context, 'Last sign-in', lastSignIn.split('T').first),
          ],
        ]),
        const SizedBox(height: 16),
        _card(context, children: [
          PressScale(
            onTap: () => context.push('/settings/change-password'),
            semanticLabel: 'Change password',
            child: Row(children: [
              Icon(Icons.lock_reset_rounded, size: 20, color: c.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Change password',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: c.text)),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: c.text3),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.infoBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, size: 20, color: c.info),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your data is protected with row-level security. Only you and the healthcare staff you visit can access your records.',
                style: AppText.caption.copyWith(color: c.info),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool mono = false}) {
    final c = context.c;
    return Row(children: [
      Expanded(child: Text(label, style: AppText.body.copyWith(color: c.text2))),
      Flexible(
        child: Text(value,
            textAlign: TextAlign.right,
            style: (mono ? AppText.mono : AppText.bodyStrong)
                .copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
      ),
    ]);
  }
}

// ── Consent management ────────────────────────────────────────────────────────
class ConsentManagementScreen extends StatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  State<ConsentManagementScreen> createState() => _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends State<ConsentManagementScreen> {
  static const _items = [
    ('share_history', 'Share full history with treating doctors', 'Doctors you visit can see your past visits, prescriptions and lab results.', true),
    ('emergency_access', 'Emergency access', 'Allow verified emergency staff to view critical info (blood group, allergies) via your card.', true),
    ('research', 'Anonymous research', 'Allow your de-identified data to support public-health research.', false),
    ('notifications', 'Health notifications', 'Receive reminders and updates about your care.', true),
  ];
  final Map<String, bool> _state = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final i in _items) {
        _state[i.$1] = prefs.getBool('consent_${i.$1}') ?? i.$4;
      }
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _state[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_$key', value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _SettingsScaffold(
      title: 'Consent management',
      children: [
        Text('Control how your health information is shared. You can change these at any time.',
            style: AppText.body.copyWith(color: c.text2)),
        const SizedBox(height: 18),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else
          for (final i in _items) ...[
            _card(context, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.$2, style: AppText.bodyStrong.copyWith(fontSize: 15, color: c.text)),
                    const SizedBox(height: 4),
                    Text(i.$3, style: AppText.caption.copyWith(color: c.text3)),
                  ]),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _state[i.$1] ?? i.$4,
                  activeTrackColor: c.primary,
                  onChanged: (v) => _set(i.$1, v),
                ),
              ]),
            ]),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 8),
        const _SectionTitle('LEGAL'),
        const SizedBox(height: 10),
        _card(context, children: [
          _navRow(context, Icons.privacy_tip_outlined, 'Privacy Policy',
              () => context.push('/legal/privacy')),
          Divider(height: 22, color: context.c.border2),
          _navRow(context, Icons.description_outlined, 'Terms & Conditions',
              () => context.push('/legal/terms')),
        ]),
        const SizedBox(height: 20),
        const _SectionTitle('YOUR DATA'),
        const SizedBox(height: 10),
        _card(context, children: [
          _navRow(context, Icons.download_rounded, 'Download my data',
              _busy ? null : _export),
          Divider(height: 22, color: context.c.border2),
          _navRow(context, Icons.delete_outline_rounded, 'Delete my account',
              _busy ? null : _requestDelete,
              danger: true),
        ]),
      ],
    );
  }

  Widget _navRow(BuildContext context, IconData icon, String label,
      VoidCallback? onTap,
      {bool danger = false}) {
    final c = context.c;
    return PressScale(
      onTap: onTap ?? () {},
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Row(children: [
          Icon(icon, size: 20, color: danger ? c.danger : c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: danger ? c.danger : c.text)),
          ),
          Icon(Icons.chevron_right_rounded, size: 22, color: c.text3),
        ]),
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ComplianceService().exportMyData();
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Your data'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(pretty,
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pretty));
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard.')));
              },
              child: const Text('Copy'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestDelete() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete your account?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'This submits a request to permanently delete your account and all '
              'your data. An administrator will process it. This cannot be undone.'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Request deletion')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ComplianceService().requestAccountDeletion(reasonCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Deletion request submitted. You will be signed out.')));
      await context.read<AuthController>().signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Request failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Legal document viewer ─────────────────────────────────────────────────────
class LegalDocScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalDocScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _SettingsScaffold(
      title: title,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.warnBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(LegalText.disclaimer,
              style: AppText.caption.copyWith(color: c.warn)),
        ),
        const SizedBox(height: 10),
        Text('Version ${LegalText.version} · Last updated ${LegalText.lastUpdated}',
            style: AppText.small.copyWith(color: c.text3)),
        const SizedBox(height: 16),
        Text(body, style: AppText.body.copyWith(color: c.text2, height: 1.5)),
      ],
    );
  }
}

// ── Help & support ────────────────────────────────────────────────────────────
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    ('How do I get my health card?', 'Open "My Card" from the dashboard and tap "Request your card". Fill in your details and photo, and a digital card is issued instantly with a unique HAY-PAT number.'),
    ('How do medicine reminders work?', 'When a doctor prescribes a medicine with a daily schedule, it appears under Prescriptions → Reminders. Mark each dose as Taken or Skipped to track your adherence.'),
    ('Who can see my medical records?', 'Only you and the healthcare staff you visit. You can fine-tune sharing under Settings → Consent management.'),
    ('How do I order a physical card?', 'From your card screen, choose "Order physical card". It is free — you only pay a small cash-on-delivery charge to the courier.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _SettingsScaffold(
      title: 'Help & support',
      children: [
        const _SectionTitle('CONTACT US'),
        const SizedBox(height: 10),
        _card(context, children: [
          _contact(context, Icons.email_rounded, 'Email', 'support@hayaat.id'),
          Divider(height: 22, color: c.border2),
          _contact(context, Icons.phone_rounded, 'Helpline', '+92 21 111 000 111'),
          Divider(height: 22, color: c.border2),
          _contact(context, Icons.schedule_rounded, 'Hours', 'Mon–Sat, 9am–9pm'),
        ]),
        const SizedBox(height: 20),
        const _SectionTitle('FREQUENTLY ASKED'),
        const SizedBox(height: 10),
        for (final f in _faqs) ...[
          _Faq(question: f.$1, answer: f.$2),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        Center(
          child: Text('HayaatID • Version 1.0.0',
              style: AppText.caption.copyWith(color: c.text3)),
        ),
      ],
    );
  }

  Widget _contact(BuildContext context, IconData icon, String label, String value) {
    final c = context.c;
    return Row(children: [
      Icon(icon, size: 20, color: c.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: AppText.body.copyWith(color: c.text2))),
      Text(value, style: AppText.bodyStrong.copyWith(fontSize: 14, color: c.text)),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: AppText.small.copyWith(
              fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: context.c.text3)),
    );
  }
}

class _Faq extends StatefulWidget {
  final String question;
  final String answer;
  const _Faq({required this.question, required this.answer});

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        PressScale(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: widget.question,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Text(widget.question,
                    style: AppText.bodyStrong.copyWith(fontSize: 14, color: c.text)),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.expand_more_rounded, color: c.text3),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(widget.answer, style: AppText.caption.copyWith(color: c.text2, height: 1.5)),
          ),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }
}
