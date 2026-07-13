import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../data/mock_data.dart' show UserPatientExtension;
import '../../models/auth_model.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emergencyCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    final ext = user?.extended ?? const {};
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _emergencyCtrl = TextEditingController(
      text: (ext['emergency_contact_name'] ?? '').toString(),
    );
    _emergencyPhoneCtrl = TextEditingController(
      text: (ext['emergency_contact_phone'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final updated = await PatientService(auth.token ?? '').updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        'emergency_contact_name': _emergencyCtrl.text.trim(),
        'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
      });
      await auth.updateCurrentUser(UserModel.fromJson(updated));
      if (!mounted) return;
      context.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final auth = context.watch<AuthController>();
    final p = auth.currentUser?.toPatient();
    if (p == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Your patient profile could not be loaded. Please sign in again.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                children: [
                  Row(
                    children: [
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
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 24,
                            color: c.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit profile',
                        style: AppText.display.copyWith(
                          fontSize: 22,
                          color: c.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: brandGradient(context),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            p.initials,
                            style: AppText.display.copyWith(
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Field(label: 'Full name', controller: _nameCtrl),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Phone number',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ReadOnlyField(
                          label: 'Blood group',
                          value: p.blood,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _Field(
                          label: 'Emergency name',
                          controller: _emergencyCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Emergency phone',
                    controller: _emergencyPhoneCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: GradientButton(
                label: 'Save changes',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: c.text2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppText.body.copyWith(color: c.text),
            cursorColor: c.primary,
            decoration: InputDecoration(
              filled: true,
              fillColor: c.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.primary, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: c.text2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Text(
            value,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
      ],
    );
  }
}
