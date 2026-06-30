import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/press_scale.dart';

/// Patient notifications, backed by the live /me/notifications feed
/// (in-app delivery of P-FR-016 / P-FR-054). Device push via FCM is a
/// production add-on requiring a Firebase project.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final PatientService _service;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _service = PatientService(context.read<AuthController>().token ?? '');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.notifications();
      if (mounted) setState(() { _items = items; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    setState(() => n['is_read'] = true);
    try {
      await _service.markNotificationRead(n['id'].toString());
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    setState(() { for (final n in _items) n['is_read'] = true; });
    try {
      await _service.markAllNotificationsRead();
    } catch (_) {}
  }

  (IconData, Color, Color) _style(BuildContext context, String type) {
    final c = context.c;
    switch (type) {
      case 'appointment_confirmed':
        return (Icons.event_available_rounded, c.safe, c.safeBg);
      case 'appointment_cancelled':
        return (Icons.event_busy_rounded, c.danger, c.dangerBg);
      case 'lab_result_ready':
      case 'lab_result_uploaded':
        return (Icons.science_outlined, c.info, c.infoBg);
      case 'doctor_approved':
        return (Icons.verified_rounded, c.safe, c.safeBg);
      case 'doctor_rejected':
        return (Icons.cancel_outlined, c.danger, c.dangerBg);
      case 'record_added':
        return (Icons.favorite_rounded, c.primary, c.mint);
      default:
        return (Icons.notifications_outlined, c.info, c.infoBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
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
                      child: Icon(Icons.chevron_left_rounded, size: 24, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Notifications',
                        style: AppText.heading.copyWith(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
                  ),
                  if (_items.any((n) => n['is_read'] == false))
                    PressScale(
                      onTap: _markAllRead,
                      semanticLabel: 'Mark all read',
                      child: Text('Mark all read',
                          style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: c.primary)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: Builder(
                  builder: (context) {
                    if (_loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_error != null) {
                      return ListView(children: [
                        const SizedBox(height: 120),
                        Center(child: Text('$_error', style: TextStyle(color: c.danger))),
                      ]);
                    }
                    final items = _items;
                    if (items.isEmpty) {
                      return ListView(children: [
                        const SizedBox(height: 140),
                        Center(child: Text('No notifications yet.', style: TextStyle(color: c.text3))),
                      ]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final n = items[i];
                        final (icon, fg, bg) = _style(context, n['type']?.toString() ?? '');
                        final created = n['created_at']?.toString() ?? '';
                        final unread = n['is_read'] == false;
                        return PressScale(
                          onTap: () => _markRead(n),
                          semanticLabel: n['title']?.toString() ?? 'Notification',
                          child: AppCard(
                            radius: 16,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icon, color: fg, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['title']?.toString() ?? '',
                                          style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
                                      const SizedBox(height: 3),
                                      Text(n['body']?.toString() ?? '',
                                          style: AppText.caption.copyWith(fontSize: 12.5, height: 1.4, color: c.text2)),
                                      const SizedBox(height: 6),
                                      Text(created.length >= 10 ? created.substring(0, 10) : created,
                                          style: AppText.small.copyWith(fontSize: 11, color: c.text3)),
                                    ],
                                  ),
                                ),
                                if (unread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
