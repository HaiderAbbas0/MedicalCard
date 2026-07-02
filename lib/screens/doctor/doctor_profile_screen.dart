import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Doctor edits their public profile: bio, consultation fee, specialization,
/// and availability toggle (Scope §7.2, P-FR-035).
class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late final DoctorService _service;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _specCtrl;
  bool _available = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _service = DoctorService(auth.token ?? '');
    final ext = auth.currentUser?.extended ?? const {};
    _bioCtrl = TextEditingController(text: ext['bio']?.toString() ?? '');
    _feeCtrl = TextEditingController(text: ext['consultation_fee_pkr']?.toString() ?? '');
    _specCtrl = TextEditingController(text: ext['specialization_primary']?.toString() ?? '');
    _available = ext['is_available'] != false;
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _feeCtrl.dispose();
    _specCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _service.updateProfile({
        'specialization_primary': _specCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'consultation_fee_pkr': num.tryParse(_feeCtrl.text.trim()),
        'is_available': _available,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = context.read<AuthController>().currentUser?.name ?? '';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'Edit profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(name, style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          _label(context, 'Primary specialization'),
          TextField(controller: _specCtrl, decoration: _dec(context)),
          const SizedBox(height: 16),
          _label(context, 'Consultation fee (PKR)'),
          TextField(controller: _feeCtrl, keyboardType: TextInputType.number, decoration: _dec(context)),
          const SizedBox(height: 16),
          _label(context, 'Public bio'),
          TextField(controller: _bioCtrl, maxLines: 4, decoration: _dec(context)),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Available for appointments', style: TextStyle(color: c.text)),
            subtitle: Text('Turn off to pause new bookings without deactivating.', style: TextStyle(color: c.text3, fontSize: 12)),
            value: _available,
            activeThumbColor: c.primary,
            onChanged: (v) => setState(() => _available = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: c.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: context.c.text2, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  InputDecoration _dec(BuildContext context) => InputDecoration(
        filled: true,
        fillColor: context.c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
