import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/card_model.dart';

class _Palette {
  final List<Color> grad;
  final Color fg;
  final bool light;
  const _Palette(this.grad, this.fg, this.light);
}

_Palette _paletteFor(String role) {
  switch (role) {
    case 'doctor':
      return const _Palette([Color(0xFF143C73), Color(0xFF2E84C7)], Colors.white, false);
    case 'lab_worker':
      return const _Palette([Color(0xFFB5641A), Color(0xFFEFA63E)], Colors.white, false);
    case 'receptionist':
      return const _Palette([Color(0xFFF7FAF9), Color(0xFFE7EEEB)], Color(0xFF0F2433), true);
    case 'admin':
      return const _Palette([Color(0xFF8E2E69), Color(0xFFD6589B)], Colors.white, false);
    default: // patient
      return const _Palette([Color(0xFF0C6E63), Color(0xFF1BA866)], Colors.white, false);
  }
}

String roleLabel(String role) => switch (role) {
      'doctor' => 'Doctor',
      'lab_worker' => 'Lab Technician',
      'receptionist' => 'Receptionist',
      'admin' => 'Administrator',
      _ => 'Patient',
    };

/// Premium HayaatID virtual card.
class HayaatCard extends StatelessWidget {
  final CardModel card;
  final String? gender;
  const HayaatCard({super.key, required this.card, this.gender});

  @override
  Widget build(BuildContext context) {
    final p = _paletteFor(card.role);
    final fg = p.fg;
    final sub = fg.withValues(alpha: 0.72);
    final accent = p.light ? const Color(0xFF0C6E63) : fg;

    return AspectRatio(
      aspectRatio: 1.55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: p.grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: p.light ? Border.all(color: const Color(0xFFD7E0DC)) : null,
            boxShadow: [BoxShadow(color: p.grad.last.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 14))],
          ),
          child: Stack(
            children: [
              // ── Geometric accents ──
              Positioned(
                right: -40, top: -40,
                child: _circle(150, fg.withValues(alpha: p.light ? 0.05 : 0.10)),
              ),
              Positioned(
                right: 30, bottom: -55,
                child: _circle(120, fg.withValues(alpha: p.light ? 0.04 : 0.07)),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _TrianglePainter(fg.withValues(alpha: p.light ? 0.04 : 0.06))),
              ),
              // ── Content ──
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: 'Hayaat', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 17)),
                          TextSpan(text: 'ID', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 17)),
                        ])),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(color: fg.withValues(alpha: p.light ? 0.08 : 0.20), borderRadius: BorderRadius.circular(99)),
                          child: Text(roleLabel(card.role), style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.3)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Photo(url: card.photoUrl, name: card.nameEn ?? '', fg: fg, light: p.light),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.nameEn ?? '—',
                                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 18, height: 1.05),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if ((card.nameUr ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(card.nameUr!, style: TextStyle(color: sub, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              if ((card.city ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(children: [
                                    Icon(Icons.place_outlined, size: 13, color: sub),
                                    const SizedBox(width: 3),
                                    Text(card.city!, style: TextStyle(color: sub, fontSize: 12)),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _field('Date of Birth', card.dateOfBirth ?? '—', fg, sub),
                        _field('Blood', card.bloodGroup ?? '—', fg, sub),
                        if ((gender ?? '').isNotEmpty) _field('Gender', _cap(gender!), fg, sub),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(card.cardNumber,
                            style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.2, fontFamily: 'monospace')),
                        const Spacer(),
                        SvgPicture.asset('assets/images/hayaat_logo.svg', width: 24, height: 24,
                            colorFilter: p.light ? null : ColorFilter.mode(fg.withValues(alpha: 0.85), BlendMode.srcIn)),
                      ],
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

  static Widget _circle(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _field(String label, String value, Color fg, Color sub) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: sub, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String? url;
  final String name;
  final Color fg;
  final bool light;
  const _Photo({required this.url, required this.name, required this.fg, required this.light});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).map((e) => e[0]).take(2).join().toUpperCase();
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: light ? 0.10 : 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fg.withValues(alpha: 0.55), width: 2),
        image: (url != null && url!.isNotEmpty) ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: (url == null || url!.isEmpty)
          ? Text(initials, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 26))
          : null,
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.42, size.height)
      ..lineTo(0, size.height * 0.45)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
