# Firestore権限修正・本番反映（2026-10-01）

ユーザー指定の8項目を修正。本番 `gyutto-cb454` の `cloud.firestore` に2026-10-01 10:53:01 JSTに反映し、再取得したルールがローカルと完全一致することを確認。

- Ruleset: `dfba9adc-1300-47ec-91a4-096bf2fed29c`
- SHA256: `f7d965dfda91b2730f6e1e21be703b04753871d72d7f84a03f83704902dadd2a`
- 本番データの変更・不正操作の再現は行っていない。Functionsは変更していない。

## 変更

1. メンバー更新・削除は同じ家族のactiveな管理者・親だけに許可。子どもの自己昇格とバッチ内昇格も拒否。本人確認に使う権限はmembersの操作前データを参照。
2. 子どもによる保護者削除を拒否。adminUserIdに対応する管理者の削除・降格・停止も拒否。
3. 家族の通常更新はnameとupdatedAtのみ。初期管理者作成は同じ操作で新しい家族を作成する場合のみ許可。
4. 所属判定はstatus=activeを必須化。停止中のメンバーはチャット読取・一覧・投稿等を拒否。
5. 投稿UIDは認証UID、表示名はmembersの表示名と一致必須。投稿時刻・既読時刻はサーバー時刻、投稿フィールドと本文の型も検査。
6. メッセージ更新はaffectedKeysで既読だけに限定し、本人の既読情報だけ更新可能。
7. 再設定申請は同じ家族のactiveな管理者・親、またはactiveな対象本人だけ閲覧可能。クライアント書込みは全面拒否し、承認等は信頼されたサーバー処理に限定。approveChildPasswordResetは本番未実装であり、この修正で機能追加はしていない。
8. 親招待とコード索引はactiveな管理者だけ作成可能。子ども招待とトークン索引はactiveな管理者・親だけ作成可能。

管理者・親が非オーナーメンバーのroleを変更できるのはユーザー指定の仕様。管理者引継ぎの新機能は追加していない。usersのプロフィール文書を権限の根拠には使用しない。ダウンロード済み端末データの消去はルールの対象外。

## 検証

`cd app; npm.cmd run test:rules:all`

Firestore Emulator（架空データ、gyutto-rules-test、127.0.0.1:8397）で以下が成功。

- 新規権限回帰テスト49項目（不正操作拒否と管理者・親・子どもの正常操作）
- 親招待26ケース・子ども招待27ケース
- 既存Firestoreルールテスト
- 参加承認の閲覧権限テスト（6ユーザー種別）
- Cloud Functions参加承認の単体テスト8件

古い基本テストの「親は参加申請を閲覧不可」という期待値を、既存実装・専用テストに合わせて修正。

本番反映後に管理APIでルールの完全一致を確認。実端末での確認は未実施。既存の不正データ・侵害履歴の調査や、アプリ全体の安全性監査を完了したという意味ではない。

取得記録とログは `app/build/production-audit/permissions-deployed.json`、`permissions-test.log`、`permissions-deploy.log`（build配下のためcleanで消える）。

## コミット後の再検証（2026-10-01）

修正を `5be7c2f` にコミットした後、以下を再実行して成功。

- Flutter analyze: No issues found。
- Flutter test: 29件成功。
- Firestore回帰テスト一式: 新規49項目、親招待26ケース、子ども招待27ケース、既存ルール・参加承認閲覧権限テスト成功。
- Functions単体テスト: 8件成功。
- Auth + Firestore + Functions Emulator統合テスト: 15項目成功。本番と同じNode.js 22（ローカル22.23.3）でも再実行して成功。

統合テストは `demo-gyutto-flow` の架空ユーザーで、メール登録・再ログイン、匿名子ども登録、家族作成、親招待参加、親による子ども招待、参加申請、実際のcallable Functionによる親の承認・管理者の拒否、管理者/親/子どものチャット投稿・読取・既読、利用停止・再開を確認。承認待ち・家族外のチャット閲覧、家族外の承認、子どもの自己昇格は拒否される。

再実行（Node.js 22を利用）：

```powershell
cd app
npm.cmd run test:rules:all
npm.cmd run test:flow
flutter analyze
flutter test
```

端末の標準Nodeが24の場合、統合テストは以下でも実行できる。

```powershell
npx.cmd --yes --package=node@22 node node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --config firebase.flow-test.json --only auth,firestore,functions --project demo-gyutto-flow "node firebase.flow.test.cjs"
```

初回の回帰テスト再起動は前回Emulatorのポート競合で失敗したため、再検証のみ8597番ポートを使用。Flutterの画面キャプチャテストが生成したストア画像の差分は取り消した。

### 本番との照合

2026-10-01 11:01 JSTに管理APIから取得。

- Firestore: 上記rulesetが適用済みで、コミット済み `firestore.rules` とバイト単位で完全一致。
- Functions: `us-central1/reviewChildJoinRequest` はACTIVE、runtime=nodejs22。
- Functionsのデプロイ済みソースZIP（generation=1789351544508233）を取得し、`index.js`、`package.json`、`package-lock.json`がローカルとバイト単位で完全一致。
- `index.js` SHA256: `9764fc8688504b9a86b73d793618d1f64ac0a3c0590143bc1c46b8dab9985702`
- 本番はすでに検証済み内容と一致しているため、今回の再検証で再デプロイは行っていない。

実端末・本番アカウントでの操作テストは行っていない。統合テストはアプリと同じFirebase操作をSDKから実行し、画面操作はFlutterテストで別途確認。本番Auth設定・IAM等すべての構成がEmulatorと同一であるという保証ではない。

取得結果: `app/build/production-audit/post-commit-production.json`
ログ: 同ディレクトリの `post-commit-rules.log`、`post-commit-analyze.log`、`post-commit-flutter-test.log`、`full-flow-node22.log`。
