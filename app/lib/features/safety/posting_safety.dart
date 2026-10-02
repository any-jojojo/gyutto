import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_functions_service.dart';

const postingTermsText =
    '投稿規約（第1版・2026年10月2日）\n\n'
    'いじめ、差別、脅迫、暴力の助長、性的な内容、子どもを傷つける内容、なりすまし、迷惑行為は禁止です。'
    '他人の個人情報や、許可のない著作物を投稿しないでください。\n\n'
    '困った投稿・ユーザーはメニューから運営に通報できます。通報対象の投稿本文、対象者、通報者、理由は調査のため運営に送られます。'
    '運営は内容を確認し、投稿の削除や利用制限を行う場合があります。\n\n'
    '通報は緊急対応の窓口ではありません。危険を感じたら画面を閉じ、安全な場所で信頼できる大人や緊急窓口に相談してください。';

Future<bool> ensurePostingConsent(
  BuildContext context,
  String familyId,
  String uid, {
  Future<int?> Function()? loadVersion,
  Future<void> Function()? accept,
}) async {
  final version = loadVersion != null
      ? await loadVersion()
      : (await FirebaseFirestore.instance
                .doc('families/$familyId/chatAccess/$uid')
                .get(const GetOptions(source: Source.server)))
            .data()?['postingTermsVersion'];
  if (version == 1) return true;
  if (!context.mounted) return false;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('投稿前に確認してください'),
      content: const SingleChildScrollView(child: Text(postingTermsText)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('同意しない'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('規約に同意する'),
        ),
      ],
    ),
  );
  if (accepted != true) return false;
  if (accept != null) {
    await accept();
  } else {
    await FirebaseFunctionsService().call('acceptPostingTerms', {
      'familyId': familyId,
      'version': 1,
      'accepted': true,
    });
  }
  return true;
}

class ReportDialog extends StatefulWidget {
  const ReportDialog({
    super.key,
    required this.familyId,
    required this.targetId,
    required this.kind,
    this.submit,
  });
  final String familyId, targetId, kind;
  final Future<void> Function(String reason, String details)? submit;
  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _details = TextEditingController();
  String _reason = 'bullying';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.submit != null) {
        await widget.submit!(_reason, _details.text.trim());
      } else {
        await FirebaseFunctionsService().call('reportChatAbuse', {
          'familyId': widget.familyId,
          'kind': widget.kind,
          'targetId': widget.targetId,
          'reason': _reason,
          'details': _details.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '送信できませんでした。通信状態を確認し、30秒ほど待って再度お試しください。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.kind == 'message' ? '投稿を通報' : 'ユーザーを通報'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '通報は運営に送信されます。相手や家族メンバーには公開されません。投稿の通報では本文も送信されます。緊急対応の窓口ではありません。',
            ),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              items: const [
                DropdownMenuItem(value: 'bullying', child: Text('いじめ・嫌がらせ')),
                DropdownMenuItem(value: 'sexual', child: Text('性的・子どもに有害')),
                DropdownMenuItem(value: 'violence', child: Text('暴力・脅迫')),
                DropdownMenuItem(value: 'personalInfo', child: Text('個人情報')),
                DropdownMenuItem(value: 'other', child: Text('その他')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _reason = v!),
            ),
            TextField(
              controller: _details,
              enabled: !_busy,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '補足（任意）',
                helperText: '必要以上の個人情報は書かないでください。',
              ),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? '送信中…' : '運営に通報する'),
        ),
      ],
    ),
  );
}

Future<void> showReport(
  BuildContext context,
  String familyId,
  String kind,
  String targetId,
) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        ReportDialog(familyId: familyId, targetId: targetId, kind: kind),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('通報を受け付けました。運営が確認します。')));
  }
}
