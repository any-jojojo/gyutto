import 'package:flutter/material.dart';
import '../settings/settings_screen.dart';
import '../../models/app_user.dart';
import '../../models/chat_safety_state.dart';
import '../../repositories/chat_safety_repository.dart';

/// The chat and its subscriptions exist only while access is allowed.
class ChatSafetyGate extends StatefulWidget {
  const ChatSafetyGate({
    super.key,
    required this.user,
    required this.builder,
    this.stateStream,
    this.onAcknowledge,
    this.onConfirmAdult,
  });
  final AppUser user;
  final WidgetBuilder builder;
  final Stream<ChatSafetyState>? stateStream;
  final Future<void> Function()? onAcknowledge;
  final Future<void> Function(String password)? onConfirmAdult;
  @override
  State<ChatSafetyGate> createState() => _ChatSafetyGateState();
}

class _ChatSafetyGateState extends State<ChatSafetyGate> {
  late final Stream<ChatSafetyState> _states;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _states =
        widget.stateStream ??
        ChatSafetyRepository().watchState(
          widget.user.familyId!,
          widget.user.uid,
        );
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '確認できませんでした。通信状態と入力内容を確認して、もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ChatSafetyState>(
    stream: _states,
    builder: (context, snapshot) {
      final state = snapshot.data;
      if (!snapshot.hasError && state?.canChat == true) {
        return widget.builder(context);
      }
      Widget content;
      if (snapshot.hasError) {
        content = const Text('利用状態を確認できません。通信状態を確認し、この画面を開き直してください。');
      } else if (state == null || !state.serverVerified) {
        content = const Text('利用状態を確認しています。インターネットに接続してください。');
      } else if (!state.active) {
        content = const Text('このアカウントではチャットを利用できません。保護者に確認してください。');
      } else if (!state.safetyAccepted) {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'チャットをはじめる前に',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            const Text(
              '・住所、電話番号、学校、パスワードなど、大切な情報は送らないでね。\n\n'
              '・送った言葉は相手に残ります。家族が読んでどう感じるか考えてから送ろう。\n\n'
              '・知らない人に招待コードを教えたり、会う約束をしたりしないでね。\n\n'
              '・こわいこと、いやなことがあったら、ひとりで悩まず信頼できる大人に相談しよう。',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _perform(
                      widget.onAcknowledge ??
                          () => ChatSafetyRepository().acknowledge(
                            widget.user.familyId!,
                          ),
                    ),
              child: const Text('読んで確認しました'),
            ),
          ],
        );
      } else if (state.isAdult && !state.adultConfirmed) {
        content = AdultConfirmationForm(
          busy: _busy,
          onConfirm: (password) => _perform(
            () =>
                widget.onConfirmAdult?.call(password) ??
                ChatSafetyRepository().confirmAdult(
                  widget.user.familyId!,
                  password,
                ),
          ),
        );
      } else {
        content = Text(
          state.permission == 'paused'
              ? 'チャットは保護者によりお休み中です。再開について保護者に相談してください。'
              : '保護者の利用許可を待っています。保護者のホーム画面から「子どものチャット利用」を開いてもらってください。',
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('チャットの安全確認'),
          actions: const [SettingsButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              content,
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class AdultConfirmationForm extends StatefulWidget {
  const AdultConfirmationForm({
    super.key,
    required this.busy,
    required this.onConfirm,
  });
  final bool busy;
  final Future<void> Function(String) onConfirm;
  @override
  State<AdultConfirmationForm> createState() => _AdultConfirmationFormState();
}

class _AdultConfirmationFormState extends State<AdultConfirmationForm> {
  final _password = TextEditingController();
  bool _declared = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('保護者の確認', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      const Text('この先は保護者が操作してください。保護者アカウントのパスワードを入力してください。'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _declared,
        onChanged: widget.busy
            ? null
            : (value) => setState(() => _declared = value ?? false),
        title: const Text('私は18歳以上で、この家族の子どもの利用を管理する保護者です。'),
      ),
      TextField(
        controller: _password,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        enabled: !widget.busy,
        decoration: const InputDecoration(labelText: '保護者のパスワード'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: !_declared || widget.busy
            ? null
            : () async {
                final password = _password.text;
                _password.clear();
                await widget.onConfirm(password);
              },
        child: const Text('保護者として確認する'),
      ),
    ],
  );
}
