import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/card_controller.dart';
import '../../services/card_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Order a physical HayaatID card — the card is free, only delivery is paid,
/// collected as Cash on Delivery.
class PhysicalCardScreen extends StatefulWidget {
  const PhysicalCardScreen({super.key});

  @override
  State<PhysicalCardScreen> createState() => _PhysicalCardScreenState();
}

class _PhysicalCardScreenState extends State<PhysicalCardScreen> {
  final _service = CardService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthController>().currentUser;
    _nameCtrl.text = u?.name ?? '';
    _emailCtrl.text = u?.email ?? '';
    _phoneCtrl.text = u?.phone ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in name, phone, and delivery address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final card = await _service.requestPhysical(address: _addressCtrl.text.trim(), phone: _phoneCtrl.text.trim());
      if (!mounted) return;
      context.read<CardController>().setCard(card);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed — pay the delivery charge when your card arrives.')),
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
      appBar: const BrandAppBar(title: 'Order physical card'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.mint, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.local_shipping_outlined, color: c.mintFg, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The card is free. You only need to pay the delivery charges upon delivery (Cash on Delivery).',
                  style: AppText.body.copyWith(color: c.text2, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          _label(context, 'Full name'),
          _field(_nameCtrl, 'Your full name'),
          const SizedBox(height: 14),
          _label(context, 'Email'),
          _field(_emailCtrl, 'you@email.com', keyboard: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _label(context, 'Contact phone number'),
          _field(_phoneCtrl, '03XX XXXXXXX', keyboard: TextInputType.phone),
          const SizedBox(height: 14),
          _label(context, 'Delivery address'),
          _field(_addressCtrl, 'House, street, area, city', maxLines: 3),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppText.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm order (Cash on Delivery)', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(backgroundColor: c.primary, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('No upfront payment required.', style: AppText.small.copyWith(color: c.text3))),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: AppText.caption.copyWith(color: context.c.text2, fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController ctrl, String hint, {TextInputType? keyboard, int maxLines = 1}) {
    final c = context.c;
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
      ),
    );
  }
}
