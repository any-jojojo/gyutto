// Standalone visual preview. Never initializes Firebase or stores credentials.
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/safety/chat_safety_gate.dart';
import '../features/safety/child_chat_controls_screen.dart';
import '../models/app_user.dart';
import '../models/chat_safety_state.dart';
import '../models/family_member.dart';
import '../repositories/chat_safety_repository.dart';

void main() => runApp(const ChatSafetyPreview());

const previewParent = AppUser(
  uid: 'preview-parent',
  displayName: 'お母さん',
  email: null,
  familyId: 'preview',
  role: AppUserRole.parent,
);
const previewChild = AppUser(
  uid: 'preview-child',
  displayName: 'はる',
  email: null,
  familyId: 'preview',
  role: AppUserRole.child,
);
const previewMembers = [
  FamilyMember(
    id: 'preview-child',
    userId: 'preview-child',
    displayName: 'はる',
    role: AppUserRole.child,
    status: FamilyMemberStatus.active,
    createdBy: 'preview-parent',
    createdAt: null,
    updatedAt: null,
  ),
];

class PreviewSafetyRepository extends ChatSafetyRepository {
  final _changes = StreamController<void>.broadcast(sync: true);
  bool acknowledged = false;
  bool confirmed = false;
  String permission = 'pending';

  ChatSafetyState state(String uid) => ChatSafetyState(
    role: uid == previewChild.uid ? 'child' : 'parent',
    active: true,
    serverVerified: true,
    safetyAccepted: uid == previewChild.uid ? acknowledged : true,
    adultConfirmed: confirmed,
    permission: permission,
  );
  @override
  Stream<ChatSafetyState> watchState(String familyId, String uid) =>
      Stream.multi((c) {
        final subscription = _changes.stream.listen((_) => c.add(state(uid)));
        c.add(state(uid));
        c.onCancel = subscription.cancel;
      });
  @override
  Future<void> acknowledge(String familyId) async {
    acknowledged = true;
    _changes.add(null);
  }

  @override
  Future<void> confirmAdult(String familyId, String password) async {
    if (password != 'preview') throw StateError('Use the preview password.');
    confirmed = true;
    _changes.add(null);
  }

  @override
  Future<void> setPermission(
    String familyId,
    String childUserId,
    String permission,
    String password,
  ) async {
    if (!confirmed || password != 'preview') {
      throw StateError('Use the preview password.');
    }
    this.permission = permission;
    _changes.add(null);
  }

  void scenario(int index) {
    acknowledged = index != 0;
    confirmed = index >= 2;
    permission = index == 3
        ? 'allowed'
        : index == 4
        ? 'paused'
        : 'pending';
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

class ChatSafetyPreview extends StatefulWidget {
  const ChatSafetyPreview({super.key, this.theme});
  final ThemeData? theme;
  @override
  State<ChatSafetyPreview> createState() => _ChatSafetyPreviewState();
}

class _ChatSafetyPreviewState extends State<ChatSafetyPreview> {
  final repository = PreviewSafetyRepository();
  int generation = 0;
  @override
  void dispose() {
    repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: widget.theme ?? AppTheme.light(),
    home: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 840;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ぎゅっと｜チャット安全機能',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('操作できる画面プレビュー・架空の家族です。本番のデータは変わりません。'),
                    const SizedBox(height: 8),
                    const SelectableText(
                      '確認用パスワード：preview（実際のパスワードは入力しないでください）',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in [
                          '最初から',
                          '成人確認',
                          '利用許可待ち',
                          '利用許可済み',
                          '利用停止中',
                        ].asMap().entries)
                          SizedBox(
                            width: 148,
                            child: OutlinedButton(
                              onPressed: () {
                                repository.scenario(entry.key);
                                setState(() => generation++);
                              },
                              child: Text(entry.value),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _phone('子どもの画面', false)),
                          const SizedBox(width: 24),
                          Expanded(child: _phone('保護者の画面', true)),
                        ],
                      )
                    else ...[
                      _phone('子どもの画面', false),
                      const SizedBox(height: 24),
                      _phone('保護者の画面', true),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _phone(String label, bool parent) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Center(
        child: Container(
          width: 390,
          height: 700,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB8D8F7), width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: MaterialApp(
            key: ValueKey((parent, generation)),
            debugShowCheckedModeBanner: false,
            theme: widget.theme ?? AppTheme.light(),
            home: parent
                ? ChildChatControlsScreen(
                    user: previewParent,
                    safetyRepository: repository,
                    membersStream: Stream.value(previewMembers),
                  )
                : ChatSafetyGate(
                    user: previewChild,
                    stateStream: repository.watchState(
                      'preview',
                      previewChild.uid,
                    ),
                    onAcknowledge: () => repository.acknowledge('preview'),
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('家族チャット')),
                      body: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Color(0xFF347568),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'チャットを利用できる状態です。',
                                style: TextStyle(fontSize: 20),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '保護者の画面で「利用を停止する」を押すと、\nこの画面もお休み中に変わります。',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}
