import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/chat_safety_state.dart';
import '../../models/family_member.dart';
import '../../repositories/chat_safety_repository.dart';
import '../../repositories/family_repository.dart';
import 'chat_safety_gate.dart';

class ChildChatControlsScreen extends StatefulWidget {
  const ChildChatControlsScreen({
    super.key,
    required this.user,
    this.safetyRepository,
    this.membersStream,
  });
  final AppUser user;
  final ChatSafetyRepository? safetyRepository;
  final Stream<List<FamilyMember>>? membersStream;
  @override
  State<ChildChatControlsScreen> createState() =>
      _ChildChatControlsScreenState();
}

class _ChildChatControlsScreenState extends State<ChildChatControlsScreen> {
  late final ChatSafetyRepository _repository;
  late final Stream<ChatSafetyState> _state;
  late final Stream<List<FamilyMember>> _members;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _repository = widget.safetyRepository ?? ChatSafetyRepository();
    _state = _repository.watchState(widget.user.familyId!, widget.user.uid);
    _members =
        widget.membersStream ??
        FamilyRepository().watchMembers(widget.user.familyId!);
  }

  Future<void> _confirm(String password) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.confirmAdult(widget.user.familyId!, password);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '保護者の確認ができませんでした。パスワードと通信状態を確認してください。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('子どものチャット利用')),
    body: StreamBuilder<ChatSafetyState>(
      stream: _state,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (snapshot.hasError) {
          return const Center(child: Text('利用状態を確認できません。画面を開き直してください。'));
        }
        if (state == null || !state.serverVerified) {
          return const Center(child: Text('利用状態を確認しています。インターネットに接続してください。'));
        }
        if (!state.active || !state.isAdult) {
          return const Center(child: Text('有効な保護者アカウントで開いてください。'));
        }
        if (!state.adultConfirmed) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AdultConfirmationForm(busy: _busy, onConfirm: _confirm),
              if (_error != null) Text(_error!),
            ],
          );
        }
        return StreamBuilder<List<FamilyMember>>(
          stream: _members,
          builder: (context, members) {
            if (members.hasError) {
              return const Center(child: Text('家族の情報を読み込めませんでした。'));
            }
            if (!members.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final children = members.data!
                .where((member) => member.role == AppUserRole.child)
                .toList();
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '参加承認とチャットの利用許可は別の設定です。利用許可後も、お子さまが安全案内を確認するまでチャットは開けません。',
                ),
                const SizedBox(height: 16),
                if (children.isEmpty) const Text('参加承認済みの子どもはいません。'),
                for (final child in children)
                  _ChildPermissionCard(
                    key: ValueKey(child.userId),
                    familyId: widget.user.familyId!,
                    member: child,
                    repository: _repository,
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _ChildPermissionCard extends StatefulWidget {
  const _ChildPermissionCard({
    super.key,
    required this.familyId,
    required this.member,
    required this.repository,
  });
  final String familyId;
  final FamilyMember member;
  final ChatSafetyRepository repository;
  @override
  State<_ChildPermissionCard> createState() => _ChildPermissionCardState();
}

class _ChildPermissionCardState extends State<_ChildPermissionCard> {
  late final Stream<ChatSafetyState> _state;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _state = widget.repository.watchState(
      widget.familyId,
      widget.member.userId,
    );
  }

  Future<void> _change(bool allow) async {
    final password = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) =>
          _PermissionDialog(name: widget.member.displayName, allow: allow),
    );
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.setPermission(
        widget.familyId,
        widget.member.userId,
        allow ? 'allowed' : 'paused',
        password,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('変更できませんでした。保護者のパスワードと通信状態を確認してください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ChatSafetyState>(
    stream: _state,
    builder: (context, snapshot) {
      final state = snapshot.data;
      final enabled =
          !snapshot.hasError && state?.serverVerified == true && !_busy;
      final allowed = state?.permission == 'allowed';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.member.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.hasError
                    ? '状態を確認できません'
                    : allowed
                    ? '利用を許可しています'
                    : state?.permission == 'paused'
                    ? '利用を停止しています'
                    : '利用は未許可です',
              ),
              if (state != null && !state.safetyAccepted)
                const Text('子どもの安全案内の確認はまだです。'),
              if (state != null && !state.active)
                const Text('メンバー自体が停止中のため、利用許可だけではチャットは再開しません。'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: enabled ? () => _change(!allowed) : null,
                child: Text(
                  allowed
                      ? '利用を停止する'
                      : state?.permission == 'paused'
                      ? '利用を再開する'
                      : '利用を許可する',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({required this.name, required this.allow});
  final String name;
  final bool allow;
  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  final _password = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.allow ? '${widget.name}さんの利用を許可' : '${widget.name}さんの利用を停止',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.allow
                ? '家族内でメッセージ、表示名、既読情報が共有されます。自由な文章には個人情報が含まれることがあります。内容を確認し、保護者として利用を許可してください。いつでも停止できます。'
                : '新しいメッセージの閲覧・送信を停止します。すでに端末に届いた内容を取り消すものではありません。',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: '保護者のパスワード'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _password.text),
        child: Text(widget.allow ? '同意して許可する' : '停止する'),
      ),
    ],
  );
}
