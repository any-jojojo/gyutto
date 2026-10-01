# チャット安全機能（2026-10-01）

## 利用方法

- 全メンバーはチャットを開く前に安全案内を読み、「読んで確認しました」を押す。
- 管理者・親は18歳以上の保護者であることを確認し、Firebase Authenticationのパスワードで再認証する。
- 保護者ホームの「子どものチャット利用」で、参加承認済みの子どもごとに明示的に利用を許可する。
- 子どもは安全案内確認と保護者の利用許可の両方が必要。参加承認だけではチャットを利用できない。
- 保護者は同じ画面で停止・再開できる。いずれもパスワードを再入力する。
- 停止中、未確認、通信により利用状態を確認できない間はチャットを表示しない。設定・アカウント削除の導線は残す。

## サーバー側

Cloud Functions（Node.js 22）:

- acknowledgeChatSafety: activeな本人の安全案内バージョンと確認日時だけを更新する。
- confirmAdultForChat: 同じ家族のactiveな管理者・親、password認証、5分以内のauth_time、成人・保護者の確認を要求する。
- setChildChatPermission: 同じ家族のactiveな管理者・親、成人確認済み、5分以内のpassword認証を要求する。対象は同じ家族のchildのみ。利用許可・停止をトランザクションで記録する。

Firestore:

- families/{familyId}/chatAccess/{uid} に安全案内確認、成人確認、利用許可を保存する。
- chatSafetyEventsに許可・停止の操作者、対象、バージョン、日時を保存する。
- 両コレクションのクライアントからの書込・削除は禁止。Functionsからのみ更新する。
- messagesの読取・一覧・投稿・既読更新はactiveな所属とsafetyVersion=1を必須にする。childはpermission=allowedかつpermissionVersion=1、管理者・親はadultVersion=1も必要。
- 記録のない既存アカウントも未確認扱い。古いアプリには案内・許可操作がないため更新が必要。
- 利用状態はキャッシュだけでは許可せず、サーバーからの確認後にチャットを生成・購読する。停止通知でチャットのWidgetを破棄する。

## 成人確認の範囲

成人の自己申告と保護者アカウントのパスワード再認証を組み合わせた保護者操作の確認。身分証による実年齢・親子関係の証明ではない。パスワード自体はFunctionsに送らず、Authの再認証結果をサーバーが検証する。生年月日や身分証を収集しない。

参考: https://support.google.com/googleplay/android-developer/answer/9893335?hl=ja

## 検証

- Flutter analyze: No issues found。
- Flutter test: 32件成功（安全案内、許可待ち、停止時のチャット除去、キャッシュでの解除拒否、成人確認フォームを含む）。
- Auth/Firestore/Functions統合テスト: Node.js 22、21項目成功。
- 既存権限回帰テスト49項目、親招待26ケース、子ども招待27ケース、参加承認閲覧テスト成功。
- Functions単体テスト: 既存8件＋安全機能17件成功。子ども、停止中の親、別家族、匿名認証、古い再認証、未確認の親による変更を拒否。
- 新しいFirestore安全機能テスト40項目成功。未確認・未許可・旧バージョン・停止中のget/list/create/updateを拒否し、保護者を含むクライアントの確認記録改ざんも拒否。

再実行:

```powershell
cd app
npm.cmd run test:safety
flutter analyze
flutter test
```

Functionsの統合テストにはNode.js 22を使用。端末が別バージョンの場合:

```powershell
npx.cmd --yes --package=node@22 node node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --config firebase.flow-test.json --only auth,firestore,functions --project demo-gyutto-flow "node firebase.safety-suite.cjs"
```

安全機能40項目の単独検証はEmulator設定ファイルをbuild配下に置いたため起動時のルールパス警告が出たが、initializeTestEnvironmentでapp/firestore.rulesを明示的にロードして検証している。

## 運用上の範囲

すでに受信・保存されたメッセージを遠隔消去する機能ではない。成人確認は法的な年齢証明ではなく、ストア審査の通過を保証しない。実機で保護者と子どもの2端末を使った最終確認は別途必要。公開前のデータセーフティ・プライバシー説明には安全案内確認、成人確認方法・時刻、利用許可・停止履歴を含める。

## 本番反映・配布物

- 2026-10-01 15:52 JST: reviewChildJoinRequest、acknowledgeChatSafety、confirmAdultForChat、setChildChatPermissionの4本をNode.js 22で配備。管理APIで全件ACTIVEを確認。
- 各Functionの配備済みZIPを取得し、index.js、chat-safety.js、package.json、package-lock.jsonの4ファイル×4本すべてがローカルとSHA256一致。
- 2026-10-01 15:54 JST: Firestoreルール反映、再取得してローカルと完全一致を確認。
- Ruleset: e47f0122-f622-41fe-aef8-96d9a5e47054
- Rules SHA256: 4f04cfd166a18ab6ed7b815d05780a551b0a2bcb7bad8b188a5a7083f311e67e
- リリースAPK: app/build/app/outputs/flutter-apk/app-release.apk（約51 MB）。flutter build apk --release成功。既存の1.0.0+2で作成した実機確認用APK。Playへ提出する際はConsole上の最新versionCodeより大きくして別途AABを作成する。
- APK SHA256: A738BD3BEF10B0227C65E84B4362A7374BDE4563BCCD2940DDC9470DCCAA2C33

旧版は新しい確認・許可操作ができないため、保護者・子どもとも更新APKが必要。既存利用者に同意済みフラグを自動付与する移行は行っていない。

Functions CLIは4本の配備成功後、Artifact Registryの自動クリーンアップポリシー未設定により終了コード1を返した。配備自体は管理APIとソース取得で成功確認済み。クリーンアップポリシーは変更していない。

本番の利用者データを操作するテストは行わず、配備済みのルール・FunctionsソースをEmulatorで検証したものに一致させた。実機確認・ストア提出は未実施。

詳細ログ・照合記録はapp/build/production-auditのsafety-*ファイル（build配下なのでcleanで削除される）。
