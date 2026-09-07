import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services/ai_insights_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'speak_button.dart';

/// Bottom sheet for the "AI assistant doctor" feature: sends one record to
/// the `explain-record` Edge Function and shows the plain-language
/// explanation it returns, with a read-aloud button.
Future<void> showAiExplainSheet(
  BuildContext context, {
  required Map<String, dynamic> record,
}) async {
  final urdu = context.read<LanguageProvider>().isUrdu;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _AiExplainSheet(record: record, urdu: urdu),
  );
}

class _AiExplainSheet extends StatefulWidget {
  final Map<String, dynamic> record;
  final bool urdu;
  const _AiExplainSheet({required this.record, required this.urdu});

  @override
  State<_AiExplainSheet> createState() => _AiExplainSheetState();
}

class _AiExplainSheetState extends State<_AiExplainSheet> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = AiInsightsService().explainRecord(widget.record, urdu: widget.urdu);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      minChildSize: .4,
      maxChildSize: .92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: brandGradient(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Explain this record',
                  style: AppText.title.copyWith(color: c.text, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.warnBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: c.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-generated general information — not a diagnosis. Always confirm with your doctor.',
                    style: AppText.caption.copyWith(color: c.warn, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    snap.error.toString().replaceFirst('Exception: ', ''),
                    style: AppText.body.copyWith(color: c.danger),
                  ),
                );
              }
              final text = snap.data ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'In plain language',
                          style: AppText.caption.copyWith(color: c.text3, fontWeight: FontWeight.w700),
                        ),
                      ),
                      SpeakButton(text: text, size: 30),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    text,
                    textDirection: widget.urdu ? TextDirection.rtl : TextDirection.ltr,
                    style: AppText.body.copyWith(color: c.text, height: 1.5),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
