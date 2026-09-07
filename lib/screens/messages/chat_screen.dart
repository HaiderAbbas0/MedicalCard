import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/speak_button.dart';
import '../../widgets/common/voice_input_button.dart';

class ChatScreen extends StatefulWidget {
  final String doctorId;
  const ChatScreen({super.key, required this.doctorId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatController>().markAsRead(widget.doctorId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    final chat = context.read<ChatController>();
    final auth = context.read<AuthController>();
    chat.sendMessage(auth.token!, widget.doctorId, t);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final convo = chat.conversations.firstWhere(
      (e) => e.doctorId == widget.doctorId,
      orElse: () => Conversation(
        doctorId: widget.doctorId,
        initials: 'Dr',
        name: 'Doctor',
        last: '',
        time: '',
        unread: 0,
        online: false,
        messages: [],
      ),
    );

    // Scroll to bottom after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: context.c.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, convo),
            Expanded(
              child: Container(
                color: context.c.bg,
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(18),
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Today',
                          style: AppText.small
                              .copyWith(fontSize: 11, color: context.c.text3),
                        ),
                      ),
                    ),
                    for (final m in convo.messages) _bubble(context, m),
                  ],
                ),
              ),
            ),
            _inputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Conversation convo) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surface,
        border: Border(bottom: BorderSide(color: context.c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          PressScale(
            onTap: () => context.pop(),
            semanticLabel: 'Back',
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.c.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.chevron_left_rounded,
                  size: 24, color: context.c.text),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.c.mint,
              shape: BoxShape.circle,
            ),
            child: Text(
              convo.initials,
              style: AppText.bodyStrong.copyWith(
                  color: context.c.mintFg, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  convo.name,
                  style: AppText.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: convo.online ? context.c.safe : context.c.text3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      convo.online ? 'Online' : 'Offline',
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: convo.online ? context.c.safe : context.c.text3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    if (!m.fromMe) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.c.surface,
            border: Border.all(color: context.c.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.text,
                style:
                    AppText.body.copyWith(fontSize: 14, color: context.c.text),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpeakButton(text: m.text, size: 24),
                  const Spacer(),
                  Text(
                    m.time,
                    style: AppText.small
                        .copyWith(fontSize: 10, color: context.c.text3),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: brandGradient(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.text,
              style: AppText.body.copyWith(fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                m.time,
                style: AppText.small.copyWith(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surface,
        border: Border(top: BorderSide(color: context.c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, 10 + MediaQuery.viewInsetsOf(context).bottom),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.c.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_rounded, size: 22, color: context.c.text2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 42,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.c.bg,
                borderRadius: BorderRadius.circular(21),
              ),
              child: TextField(
                controller: _input,
                style: AppText.body.copyWith(color: context.c.text),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Message…',
                  hintStyle: AppText.body.copyWith(color: context.c.text3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          VoiceInputButton(controller: _input, size: 38),
          const SizedBox(width: 6),
          PressScale(
            onTap: _send,
            semanticLabel: 'Send',
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: brandGradient(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
