import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'press_scale.dart';

/// The gradient Digital Health Card shown on the dashboard.
class HealthCardWidget extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onShow;

  const HealthCardWidget({super.key, required this.patient, this.onShow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brandGradient(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.brandCard,
      ),
      child: Stack(
        children: [
          // Decorative translucent circle.
          Positioned(
            right: -34,
            top: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _photo(patient.initials),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DIGITAL HEALTH CARD',
                            style: AppText.monoSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10)),
                        const SizedBox(height: 6),
                        Text(patient.name,
                            style: AppText.title.copyWith(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(patient.healthId,
                            style: AppText.mono.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  Hero(
                    tag: 'health-qr',
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: kHealthCardQr,
                        version: QrVersions.auto,
                        size: 48,
                        padding: EdgeInsets.zero,
                        // ignore: deprecated_member_use
                        foregroundColor: kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _meta('DOB', patient.dob),
                  const SizedBox(width: 28),
                  _meta('BLOOD', patient.blood),
                ],
              ),
              const SizedBox(height: 18),
              PressScale(
                onTap: onShow,
                semanticLabel: 'Show Health Card',
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Show Health Card',
                          style: AppText.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photo(String initials) {
    return Container(
      width: 60,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(initials,
          style: AppText.heading.copyWith(color: Colors.white, fontSize: 22)),
    );
  }

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.small.copyWith(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        const SizedBox(height: 3),
        Text(value,
            style: AppText.bodyStrong.copyWith(color: Colors.white)),
      ],
    );
  }
}
