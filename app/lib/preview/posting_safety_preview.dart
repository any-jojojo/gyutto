// Local-only preview: no Firebase initialization or network writes.
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/safety/posting_safety.dart';

void main() => runApp(const PostingSafetyPreview());

class PostingSafetyPreview extends StatelessWidget {
  const PostingSafetyPreview({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: const _Preview(),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _text = TextEditingController(text: 'ただいま！');
  DateTime? _acceptedAt;
  final List<String> _posts = [];
  final List<String> _reports = [];
  bool _fail = false;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final allowed = await ensurePostingConsent(
        context,
        'preview',
        'preview-child',
        loadVersion: () async => _acceptedAt == null ? null : 1,
        accept: () async {
          setState(() => _acceptedAt = DateTime.now());
        },
      );
      if (!mounted) return;
      if (allowed) {
        setState(() => _posts.add(text));
        _text.clear();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('同意していないため、投稿していません。')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(String kind) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportDialog(
        familyId: 'preview',
        targetId: kind == 'message' ? 'sample-post' : 'sample-user',
        kind: kind,
        submit: (reason, details) async {
          if (_fail) throw StateError('Preview failure');
          setState(
            () => _reports.add(
              '${kind == 'message' ? '投稿' : 'ユーザー'} / $reason${details.isEmpty ? '' : ' / $details'}',
            ),
          );
        },
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通報を受け付けました（プレビューのみ）。')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('投稿の安全機能プレビュー')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('本番には送信しません。記録はこの画面内だけで保持し、再読み込みすると消えます。'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. 投稿と規約同意',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text('最初の投稿で、実際のアプリと同じ規約画面が開きます。'),
                    TextField(
                      controller: _text,
                      decoration: const InputDecoration(labelText: 'メッセージ'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _post,
                      child: const Text('投稿する'),
                    ),
                    const Divider(),
                    Text(
                      _acceptedAt == null
                          ? '同意記録：未同意'
                          : '同意記録：第1版に同意済み\n確認日時（端末時刻・仮記録）：${_acceptedAt!.toIso8601String()}',
                    ),
                    const Text('本番では、版番号とサーバー時刻を保存します。'),
                    for (final post in _posts)
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(post),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. 投稿・ユーザーの通報',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const ListTile(
                      leading: CircleAvatar(child: Text('家')),
                      title: Text('家族メンバー（サンプル）'),
                      subtitle: Text('これは通報操作を試すためのサンプル投稿です。'),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _report('message'),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('投稿を通報'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _report('user'),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('ユーザーを通報'),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('通報の送信失敗を試す'),
                      value: _fail,
                      onChanged: (v) => setState(() => _fail = v),
                    ),
                    Text('プレビュー内の受付記録：${_reports.length}件'),
                    for (final report in _reports) Text(report),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _acceptedAt = null;
                      _posts.clear();
                      _reports.clear();
                      _fail = false;
                      _text.text = 'ただいま！';
                    }),
              child: const Text('記録をリセットして最初から'),
            ),
          ],
        ),
      ),
    ),
  );
}
