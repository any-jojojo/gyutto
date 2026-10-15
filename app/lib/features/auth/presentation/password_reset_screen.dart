import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../repositories/auth_repository.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    this.initialEmail = '',
    this.authRepository,
  });
  final String initialEmail;
  final AuthRepository? authRepository;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _sent || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await (widget.authRepository ?? AuthRepository()).sendPasswordResetEmail(
        _email.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found' || error.code == 'user-disabled') {
        setState(() => _sent = true);
      } else {
        setState(
          () => _error = switch (error.code) {
            'invalid-email' => 'メールアドレスを確認してください。',
            'too-many-requests' => '送信回数が多いため、しばらく待ってからもう一度お試しください。',
            'network-request-failed' => '通信できませんでした。通信状態を確認して、もう一度お試しください。',
            _ => '再設定メールを送信できませんでした。しばらく待ってからもう一度お試しください。',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '再設定メールを送信できませんでした。通信状態を確認して、もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('パスワードの再設定')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '家族管理者・親のアカウントで登録したメールアドレスを入力してください。届いたメールのリンクから新しいパスワードを設定できます。',
          ),
          const SizedBox(height: 24),
          if (_sent) ...[
            const Icon(Icons.mark_email_read_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              '入力したメールアドレスが登録されている場合、パスワードの再設定メールを送信しました。迷惑メールフォルダも確認してください。',
            ),
            const SizedBox(height: 16),
            const Text('メールのリンクで新しいパスワードを設定したあと、ぎゅっとに戻ってログインしてください。'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ログイン画面に戻る'),
            ),
          ] else ...[
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _email,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onFieldSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  labelText: '登録したメールアドレス',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'メールアドレスを入力してください。';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    return 'メールアドレスを確認してください。';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mail_outline),
              label: Text(_sending ? '送信中…' : '再設定メールを送信'),
            ),
          ],
          const SizedBox(height: 24),
          const Text('子供アカウントは、保護者が表示するQRコードからログインしてください。'),
        ],
      ),
    ),
  );
}
