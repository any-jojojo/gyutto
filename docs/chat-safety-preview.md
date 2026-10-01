# チャット安全機能のローカルプレビュー

起動:

```powershell
cd app
flutter run -d web-server --target lib/preview/chat_safety_preview.dart --web-hostname 127.0.0.1 --web-port 8756
```

http://127.0.0.1:8756 をブラウザで開く。

- 子どもの安全案内と保護者の成人確認・利用許可画面は製品と同じWidget。
- 確認用パスワードは `preview`。本物の認証情報を使わない。
- Firebaseは初期化せず、架空の家族・メモリ内状態だけを使用。本番データを変更しない。
- 「最初から」「成人確認」「利用許可待ち」「利用許可済み」「利用停止中」で状態を切り替えられる。
- 子ども側の確認、保護者側のチェックとパスワード入力、許可・停止・再開を操作できる。
- 許可後のチャット部分は利用可能状態の案内表示。チャット送受信・本番認証・サーバー制限の検証用ではない。

検証: `flutter test test/preview_chat_safety_test.dart test/chat_safety_gate_test.dart`（4件成功）、flutter analyze成功。
画面画像: `app/build/preview/chat-safety/`（5状態）。
操作用Browserは接続できなかったため、ブラウザ操作の自動確認は未実施。Flutter Widget上の連続操作とレンダリングで確認。
