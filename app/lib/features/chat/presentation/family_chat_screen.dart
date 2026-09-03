import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/app_user.dart';
import '../../../models/chat_message.dart';
import '../../../repositories/chat_repository.dart';

class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({
    super.key,
    required this.user,
    this.chatRepository,
    this.messagesStream,
  });

  final AppUser user;
  final ChatRepository? chatRepository;
  final Stream<List<ChatMessage>>? messagesStream;

  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends State<FamilyChatScreen> {
  final _messageController = TextEditingController();
  late final ChatRepository? _chatRepository;
  late final Stream<List<ChatMessage>> _messagesStream;
  final Set<String> _readRequests = {};
  var _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatRepository =
        widget.chatRepository ??
        (widget.messagesStream == null ? ChatRepository() : null);
    _messagesStream =
        widget.messagesStream ??
        _chatRepository!.watchMessages(widget.user.familyId!);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await (_chatRepository ?? ChatRepository()).sendMessage(
        familyId: widget.user.familyId!,
        senderUserId: widget.user.uid,
        senderDisplayName: widget.user.displayName ?? '子ども',
        text: text,
      );
      _messageController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メッセージを送信できませんでした。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _markReceivedMessagesAsRead(List<ChatMessage> messages) {
    final unreadMessages = messages.where(
      (message) =>
          message.senderUserId != widget.user.uid &&
          !message.readBy.containsKey(widget.user.uid) &&
          _readRequests.add(message.id),
    );

    for (final message in unreadMessages) {
      unawaited(_markMessageAsRead(message.id));
    }
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await (_chatRepository ?? ChatRepository()).markAsRead(
        familyId: widget.user.familyId!,
        messageId: messageId,
        userId: widget.user.uid,
        displayName: widget.user.displayName ?? '子ども',
      );
    } catch (_) {
      _readRequests.remove(messageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          children: [
            Text('家族みんな', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('家族チャット', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _ChatStatus(
                      icon: Icons.cloud_off_outlined,
                      message: 'メッセージを読み込めませんでした。',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!;
                  _markReceivedMessagesAsRead(messages);
                  if (messages.isEmpty) {
                    return const _ChatStatus(
                      icon: Icons.waving_hand_rounded,
                      message: '家族に最初のメッセージを送ってみよう！',
                    );
                  }

                  return ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        isMine: message.senderUserId == widget.user.uid,
                      );
                    },
                  );
                },
              ),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt == null
        ? ''
        : '${message.createdAt!.hour.toString().padLeft(2, '0')}:${message.createdAt!.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  message.senderDisplayName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppConstants.inkColor.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isMine && time.isNotEmpty) ...[
                  _MessageMeta(message: message, time: time),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isMine
                          ? AppConstants.connectionColor
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isMine && time.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({required this.message, required this.time});

  final ChatMessage message;
  final String time;

  @override
  Widget build(BuildContext context) {
    final readLabel = message.readBy.entries
        .where(
          (entry) =>
              entry.key != message.senderUserId &&
              entry.value.displayName.trim().isNotEmpty,
        )
        .map((entry) => '${entry.value.displayName}既読')
        .join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (readLabel.isNotEmpty)
          Text(
            readLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppConstants.inkColor.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        Text(time, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'メッセージを入力',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFFF3F5F7),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '送信',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStatus extends StatelessWidget {
  const _ChatStatus({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppConstants.inkColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
