import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/card_controller.dart';
import '../../services/card_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Request / update a HayaatID card: Urdu name, DOB, blood group, city, photo.
class CardRequestScreen extends StatefulWidget {
  const CardRequestScreen({super.key});

  @override
  State<CardRequestScreen> createState() => _CardRequestScreenState();
}

class _CardRequestScreenState extends State<CardRequestScreen> {
  final _service = CardService();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  DateTime? _dob;
  String _blood = 'unknown';
  Uint8List? _photoBytes;
  bool _busy = false;
  String? _error;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown'];

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthController>().currentUser;
    _nameCtrl.text = u?.name ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.single.bytes != null) {
      setState(() => _photoBytes = res.files.single.bytes);
    }
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
    if (_dob == null) {
      setState(() => _error = 'Please select your date of birth.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? photoUrl;
      if (_photoBytes != null) photoUrl = await _service.uploadPhoto(_photoBytes!);
      final card = await _service.requestCard(
        nameEn: _nameCtrl.text.trim(),
        dob: _dob!.toIso8601String().substring(0, 10),
        bloodGroup: _blood,
        city: _cityCtrl.text.trim(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      context.read<CardController>().setCard(card);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your card ${card.cardNumber} is ready!')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'Request your card'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Text('A few details to print on your HayaatID card.',
              style: AppText.body.copyWith(color: c.text2)),
          const SizedBox(height: 20),

          // Photo
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.primary, width: 2),
                  image: _photoBytes != null ? DecorationImage(image: MemoryImage(_photoBytes!), fit: BoxFit.cover) : null,
                ),
                alignment: Alignment.center,
                child: _photoBytes == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_outlined, color: c.primary, size: 28),
                        const SizedBox(height: 4),
                        Text('Add photo', style: AppText.caption.copyWith(color: c.primary)),
                      ])
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Clear background, good lighting, straight face',
                style: AppText.small.copyWith(color: c.text3)),
          ),
          const SizedBox(height: 22),

          _label(context, 'Name on Card'),
          TextField(controller: _nameCtrl, decoration: _dec(context, 'Full name in English')),
          const SizedBox(height: 4),
          Text('We print the Urdu version automatically.', style: AppText.small.copyWith(color: c.text3)),
          const SizedBox(height: 16),

          _label(context, 'Date of birth'),
          InkWell(
            onTap: _pickDob,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Text(
                _dob == null ? 'Select date' : _dob!.toIso8601String().substring(0, 10),
                style: AppText.body.copyWith(color: _dob == null ? c.text3 : c.text),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _label(context, 'Blood group'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _blood,
                isExpanded: true,
                items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() => _blood = v ?? 'unknown'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _label(context, 'City'),
          TextField(controller: _cityCtrl, decoration: _dec(context, 'e.g. Islamabad')),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppText.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: c.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate my card', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: AppText.caption.copyWith(color: context.c.text2, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(BuildContext context, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.c.border)),
      );
}
