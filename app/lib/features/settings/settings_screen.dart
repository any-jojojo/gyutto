import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/chat_notification_service.dart';

const accountDeletionUrl = 'https://gyutto-cb454.web.app/';
const accountDeletionEmail = 'gyutto.delete@gmail.com';
const privacyPolicyUrl = 'https://gyutto-cb454.web.app/privacy-policy';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '設定',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.openPage});

  final Future<bool> Function(Uri)? openPage;

  Future<void> _openPolicy(BuildContext context) async {
    var opened = false;
    try {
      final uri = Uri.parse(privacyPolicyUrl);
      opened =
          await (openPage?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // The direct URL remains available when no browser can open it.
    }
    if (opened || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ポリシーを開けませんでした'),
        content: const SelectableText(privacyPolicyUrl),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: privacyPolicyUrl),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('URLをコピー'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestDeletion(BuildContext context) async {
    var opened = false;
    try {
      final uri = Uri.parse(accountDeletionUrl);
      opened =
          await (openPage?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // Keep the URL and contact address available if no browser can open.
    }
    if (opened || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('申請ページを開けませんでした'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('以下のURLをブラウザで開くか、メールで削除を申請してください。'),
              SizedBox(height: 12),
              SelectableText(accountDeletionUrl),
              SizedBox(height: 12),
              SelectableText(accountDeletionEmail),
              SizedBox(height: 8),
              Text('件名：gyutto アカウント・関連データ削除申請'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: accountDeletionUrl),
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('URLをコピー'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('設定')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (ChatNotificationService.instance.supported) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('メッセージ通知'),
              subtitle: const Text('通知の許可、音、振動をスマホの設定で変更します。'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                try {
                  await ChatNotificationService.instance.openSettings();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('スマホの設定から「ぎゅっと」の通知設定を開いてください。'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            subtitle: const Text('収集する情報、利用目的、共有範囲、削除について'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openPolicy(context),
          ),
        ),
        const SizedBox(height: 16),
        Text('アカウント', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('アカウント削除を申請'),
            subtitle: const Text('アカウントと関連データの削除申請ページをブラウザで開きます。'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _requestDeletion(context),
          ),
        ),
        const SizedBox(height: 16),
        const Text('今回のバージョンでは、Webページからメールで申請を受け付けています。運営が本人確認後に対応します。'),
        const SizedBox(height: 12),
        const Text('ページを開くだけでは削除されません。削除対象や注意事項を確認してから申請してください。'),
        const SizedBox(height: 16),
        const SelectableText(accountDeletionEmail),
      ],
    ),
  );
}
