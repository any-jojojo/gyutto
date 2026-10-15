# 家族管理者・親のパスワード再設定

ログイン画面の「パスワードを忘れた方」から利用する。登録したメールアドレスを入力して再設定メールを送信し、メールのリンクをブラウザで開いて新しいパスワードを設定する。その後ぎゅっとに戻り、同じアカウントでログインする。アカウント・所属家族・チャットの削除は行わない。

- Firebase Authenticationの`sendPasswordResetEmail`を使用。メールの言語は日本語に設定する。
- ログイン画面で入力したメールアドレスを引き継ぐ。既存のパスワードの入力は不要。
- 未登録メールアドレスの場合にも登録有無を明かさない共通の案内を表示する。
- 空欄・形式不正は送信しない。送信中はボタンと入力欄を無効にし、二重送信を防止する。
- 通信失敗・送信回数制限を案内し、失敗後に再試行できる。
- 送信中に画面を閉じても例外にならない。
- 子供アカウントにはメール再設定を案内せず、既存のQRコードログインを案内する。

バックエンド関数の追加・デプロイは不要。ビルド6にはこの機能は含まれていない。

## 配布記録（2026-10-15）

- 更新版：1.0.2+7。Play APIでクローズドテスト「1005_v」へAABをアップロードし、validate・commitが成功。
- リリース名：`1.0.2 (7)`、versionCodes=`[7]`、status=`completed`。Google Playの審査・公開状況とテスター端末への反映はConsoleまたは端末で確認する。
- ファイル：`app/build/app/outputs/bundle/release/gyutto-1.0.2-build7.aab`（55,270,324 bytes）。
- SHA-256：`34133c8962e851488824590ddf356eff1385c577b433e28f13972df6e5271067`。
- AAB manifestでcom.gyutto・versionCode=7・versionName=1.0.2を確認。署名検証と、Firebase Core・Messaging・GeneratedPluginRegistrantのDEX class_def収録確認が成功。
- Firebaseへの新規デプロイは行わず、既存の通知機能を維持。

検証：`flutter test --no-pub test/password_reset_test.dart test/widget_test.dart`（23件成功）、静的解析成功。
Firebase SDK呼び出しと画面を差し替えて検証し、実在ユーザーへのメール送信は行わない。
実機では再設定メールの到着、リンクでの変更、変更後のログインを確認する。
