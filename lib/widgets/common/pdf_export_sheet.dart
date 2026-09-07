import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/report_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum _ExportAction { share, print }

/// Offers "Share / save PDF" and "Print" for a document that is built only
/// after the user picks an action. [build] returns the PDF bytes.
Future<void> showPdfExportSheet(
  BuildContext context, {
  required String title,
  required String filename,
  required Future<Uint8List> Function() build,
  ReportPdfService? service,
}) async {
  final svc = service ?? ReportPdfService();
  final c = context.c;
  final action = await showModalBottomSheet<_ExportAction>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppText.title.copyWith(color: c.text)),
            ),
          ),
          ListTile(
            leading: Icon(Icons.ios_share_rounded, color: c.primary),
            title: Text(
              'Share / save PDF',
              style: AppText.bodyStrong.copyWith(color: c.text),
            ),
            subtitle: Text(
              'Send on WhatsApp or email, or save to your device',
              style: AppText.caption.copyWith(color: c.text3),
            ),
            onTap: () => Navigator.pop(ctx, _ExportAction.share),
          ),
          ListTile(
            leading: Icon(Icons.print_outlined, color: c.primary),
            title: Text(
              'Print',
              style: AppText.bodyStrong.copyWith(color: c.text),
            ),
            subtitle: Text(
              'Open the print dialog',
              style: AppText.caption.copyWith(color: c.text3),
            ),
            onTap: () => Navigator.pop(ctx, _ExportAction.print),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Preparing PDF...'),
      duration: Duration(seconds: 2),
    ),
  );
  try {
    final bytes = await build();
    if (action == _ExportAction.share) {
      await svc.share(bytes, filename);
    } else {
      await svc.print(bytes, filename);
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}
