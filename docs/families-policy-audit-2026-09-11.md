# Familiesポリシー公開前監査 — 2026-09-11

結論：現在の状態を「子どもを対象に含むアプリとして公開準備完了」とは判定できない。最優先はFirestoreの権限修正。その後、安全案内・保護者管理・通報・規約・データ開示を整える。

## 対象と限界

- HEAD: `9f0a410a10f4d744948bc20832c999235f132a2e` と監査開始時に存在した未コミット変更。バージョン `1.0.0+2`、現在のapplicationIdは `com.gyutto`。
- Flutterコード、Firestoreルール、Cloud Functions、pubspec/lock、既存releaseのマージ済みManifest・依存レポート、削除ページのローカルソースを確認。
- 既存ビルドの情報は現在の未コミットコードと完全一致する証拠ではない。最終AABで再確認する。
- ローカルFirestore Emulatorと架空データのみで再現。プロジェクトID `demo-gyutto-families-audit`、接続先 `127.0.0.1:8297`。
- 本番Firestoreの適用ルール、Firebase Consoleの認証設定、IAM・ログ・保持設定、Play Consoleの申告、公開ページの実動作、実機通信は未確認。漏えいの発生を示す調査ではない。
- 製品コード・本番設定は変更していない。監査資料とbuild配下の検証用ファイルだけを作成。
- Googleの審査結果や各国法令への適合を保証するものではない。

## 1. 最優先：ローカルで再現した権限問題

検査対象 `app/firestore.rules` のSHA256：
`86005A70FAC3BDC0D64D0D61F92D5338C2B3AEC6C3647DB2192F56460D817CEF`

| ID | 実際に許可された操作 | 根拠 | 対応方針 |
|---|---|---|---|
| S1 | 子どもが自分のmembers.roleをfamilyAdminへ変更 | 150行：全メンバーにupdate/deleteを許可 | role/status/所属などをクライアントの自己編集から保護。管理操作を権限検査付きサーバー処理へ |
| S2 | 子どもが保護者のmembershipを削除 | 150行 | 管理者の保護、削除・退会・引継ぎの権限を個別に設計 |
| S3 | 子どもが家族のadminUserIdを外部ユーザーに変更し、その外部ユーザーが招待なしで管理者membershipを作成 | 141行とisCreatingOwnFamilyMembership | 管理者IDの変更制限と初回家族作成専用条件を追加 |
| S4 | status=suspendedの子どもがチャットの読取・投稿 | isFamilyMemberは存在だけ確認（9行）、154行 | active状態・保護者の許可状態をサーバー側でも検査 |
| S5 | 子どもが親のsenderUserId/displayNameで投稿 | messages.createに送信者検査なし（154行） | UIDを認証UIDへ固定し、表示名・時刻・本文・既読の型と範囲を検査 |
| S6 | 子どもが既存の他者メッセージからtextを除去 | changedKeys()で追加・削除を制限できていない（156行） | affectedKeys()、必須フィールド、本人分の既読情報を検査 |
| S7 | 別家族のpasswordResetRequestsを読取・更新 | 191行：ログインだけでread/writeを許可 | 対象本人・該当家族の許可された保護者だけに限定 |
| S8 | 子どもが親招待のinvitesドキュメントを作成 | 162行：全メンバーにcreateを許可 | 招待種別ごとに作成可能な成人ロールを限定。コード・トークン索引のルールも同時に修正 |

S7は申請文書の読取・変更の再現であり、Authenticationのパスワードを実際に変更した検証ではない。S8は招待文書作成までを検証し、有効な招待フロー全体の悪用までは実行していない。

対照検査では、権限改ざん前の別家族ユーザーおよび未認証ユーザーのチャット読取は拒否された。8件の危険な操作の再現＋2件の拒否確認＝10シナリオが想定どおり完了した。「安全性テストが合格」という意味ではない。

検証ファイル：`app/build/families-audit/check.cjs`、`results.json`、`emulator.log`。build配下なのでflutter cleanで消える。テストのinitializeTestEnvironmentが元のfirestore.rulesを明示的にロードしてから各検査を実行。起動時に設定用コピーの欠落警告があったが、検査開始前に元ルールをロードしており、拒否の対照検査も成功した。再実行用に同一ルールを設定ディレクトリへコピー済み。

前回の79テスト成功は、今回の権限昇格・停止状態・別家族の再設定申請等を網羅した証拠ではない。修正時には上記を「拒否されること」の回帰テストにする。

## 2. Familiesとチャット安全機能

子どもを含む自由文のやり取りには、事前のオンライン安全案内と、個人情報交換を有効にする成人の操作が求められる。ソーシャル機能については成人による管理も規定される。家族限定であることだけを免除理由にしない。[Families本文・Social Apps & Features](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)

| 項目 | 状態 | 確認内容・必要な対応 |
|---|---|---|
| 閉じた家族チャット | 一部実装 | 公開チャット・ランダム相手との接続は見当たらない。ただしS3の招待回避を修正するまで家族限定という説明を十分に裏付けられない |
| 子どもの参加承認 | 一部実装 | reviewChildJoinRequestは管理者・activeを検査してmembershipを作る。しかし管理者ロール自体がS1で書き換え可能 |
| 成人の確認 | 不十分 | ログイン・家族管理者ロールはあるが、成人確認、保護者専用の再認証、許可の記録が見当たらない。家族参加の「はい」は成人確認や規約同意ではない |
| チャット前の安全案内 | 未実装 | FamilyChatScreenで即座にメッセージ購読・送信UIを提供。初回利用前に子ども向けの注意を表示し確認を保存する |
| 保護者の管理 | 未実装 | 利用停止・再開のUIとサーバー強制が見当たらない。新設時はUIだけの制限にせずS4も修正 |
| 投稿・ユーザーの通報 | 未実装 | 投稿、ユーザーを特定してアプリ内から運営へ報告する機能が見当たらない。削除専用メール窓口は通報処理の代わりにはなっていない |
| 規約への事前同意 | 未実装 | 登録画面・投稿前に規約の提示と同意が見当たらない |
| 運営の対応 | 未確認 | 通報の受付担当、非表示・停止・調査・対応記録を運用として準備する |

UGCポリシーは限定されたユーザー群のアプリにも通報機能を求める。利用規約で禁止行為を定義し投稿前の同意を用意する。ブロックについては、公開UGCや1対1通信に明示要件がある。現状は家族グループチャットであり、1対1向け要件をそのまま断定せず、一般の報告・ブロック要件に照らして利用者保護の方法を設計する。運営通報、保護者管理、ミュート・ブロック等の選択肢を整理する。[UGCポリシー](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en)

「安全案内を読んだ」だけで成人の操作を代替しない。また、成人用の確認があれば各国法令上の保護者同意も自動的に満たすとは判断しない。

## 3. データの扱い

コードで確認したデータ：親等のメールアドレスと認証情報、子どもの匿名認証UID、表示名、家族ID・役割、本文、送信日時、既読者の表示名・UID・時刻、招待のハッシュ・期限・利用者、参加申請・承認者・承認日時。メールなしの子どもアカウントも「個人データを収集しない」にはならない。

Firestoreへ本文をそのまま渡しており、エンドツーエンド暗号化の実装は見当たらない。通信の暗号化とE2EEを混同して掲載・申告しない。

- アプリとsupport-site内に、包括的なプライバシーポリシーとアプリ内リンクを確認できなかった。外部の別ページが存在するかは未確認。
- データ収集目的、家族内で見える範囲、委託先、保存・削除、問い合わせ、子どもの利用について実装に合わせて記載する。[User Data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- 削除申請のWebリンクとメール窓口、運用手順は存在する。ただし削除の実行・本人確認・対応期限の運用は未検証。申請可能なWeb経路自体は許容されるため、自動削除が必須という指摘ではない。[削除要件](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- 公開ページの「原則30日以内」と、クラウド側バックアップ等の処理期間を区別する。Firebaseの資料ではAuth情報の削除後のlive/backup処理に最大180日の記載がある。全コピーが30日以内に消えると約束しない。[Firebaseの保持情報](https://firebase.google.com/support/privacy)
- 未承認・拒否済み匿名アカウント、古い招待、ログ、端末キャッシュの保持・消去も確認する。これらの自動清掃は今回確認したコードに見当たらない。
- データセーフティの「収集」「共有」の最終回答は、委託処理やユーザー主導の共有の例外も踏まえて決める。Firebase利用だけを理由に一律の回答をしない。[データセーフティ](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

## 4. SDKとAndroid権限

| SDK・構成 | 確認結果 |
|---|---|
| firebase_auth 6.5.6 / Android firebase-auth 24.1.0 | メール・パスワード／匿名認証を使用。SDKのIP、UID、user agent等の処理を開示に含める |
| cloud_firestore 6.7.1 / Android firebase-firestore 26.4.0 | 本文・所属・既読等を送信。認証UIDとuser agentも考慮 |
| cloud_functions 6.3.5 / Android firebase-functions 22.1.1 | 参加承認等。UID、IP等を考慮 |
| firebase_core 4.12.1 | 起動時にFirebase初期化 |
| firebase-installations 19.1.1、firebase-iid 21.1.0 | 既存release依存レポートに含まれる。アプリインスタンス識別子・トークンの確認が必要 |
| reCAPTCHA 18.6.1、Play services auth/fido等 | 推移的依存に含まれる。含有だけで該当機能の実行や禁止情報送信とは断定しない。最終構成の利用条件と実行経路を確認 |
| qr_flutter、crypto、url_launcher | QR生成・ハッシュ・外部ページ起動に使用。独自の広告処理は見当たらない |
| 広告・Analytics・Crashlytics | 確認したアプリコード・依存レポートに該当SDKは見当たらない |

Firebaseの公式開示資料では、FunctionsのFCMトークン処理はFCM SDKの明示導入の有無と独立する旨がある。InstallationsのFIDも確認対象。広告IDがなくてもSDKデータ処理はゼロではない。[Firebase Android開示資料](https://firebase.google.com/docs/android/play-data-disclosure)

既存releaseのマージ済みManifestで、AD_ID、カメラ、マイク、位置情報、連絡先、READ_PHONE_STATE、Bluetooth権限は見当たらない。INTERNET、ACCESS_NETWORK_STATE、READ_GSERVICES、WAKE_LOCK、C2DM RECEIVE等は含まれる。権限の不在だけで禁止識別子を送信しないことを完全証明はできない。

Firebase各SDKを一括して「Families認定済み」とは表現しない。広告SDKの自己認定制度と一般SDKの利用適格性は別問題。主要サービスの適用規約は確認したが、子ども向け利用可否の全SDK・全実行経路の確定まではしていない。[Firebase適用規約](https://firebase.google.com/terms)・[GCP規約](https://cloud.google.com/terms)・[サービス固有規約](https://cloud.google.com/terms/service-terms)

年齢画面は、広告や子ども向け非対応SDKの利用条件に応じて設計する。広告のない本アプリに単に年齢入力を足すだけで適合になるわけではない。利用不可なSDKを全員から外す方法もある。役割名の「親」は実年齢の確認ではない。

## 5. Console・運用で追加確認すること

- 正確な対象年齢と配信国。掲載文に子どもの利用を明示しているため、申告だけを成人向けに変更して回避しない。
- コンテンツレーティングで自由文チャット・情報交換を申告する。
- Socialカテゴリ等の適用対象ならChild Safety Standardsに沿う公開基準、アプリ内フィードバック、CSAM対応、連絡担当者も整える。Firebaseの匿名認証は内部認証方式であり、それだけで「匿名チャットアプリ」に分類されるとは判断しない。[Child Safety Standardsの適用範囲](https://support.google.com/googleplay/android-developer/answer/14747720?hl=en)
- Firebaseの本番ルールとFunctionsが検証コードに一致すること、ログ・バックアップ・データ保存場所、reCAPTCHA/認証関連の設定を確認する。
- 審査用アカウントと親・子ども双方の確認手順を用意する。

## 対応順序と再検証条件

1. AI：S1～S8の権限とデータ検証を修正し、拒否の回帰テストと既存の正常フローを検証する。
2. AI＋運営者：成人確認、子どもの利用許可・停止、初回安全案内を設計・実装する。サーバー側の強制も検証する。
3. AI＋運営者：通報・対応手順、利用規約と投稿前同意を整える。通報が対象の問題ユーザーに漏れない権限も検証する。
4. AI：データ一覧とSDK一覧を確定し、プライバシーポリシー・アプリ内リンク・削除説明・データセーフティ回答案を揃える。
5. 運営者：対象年齢・国・受付担当・対応期限を確定し、実際の削除・通報対応を検証する。
6. AI＋運営者：最終AAB、実機の親子フロー、SDK起動時の通信、本番適用状態、Console申告を照合して公開判断する。

現時点の判定は「公開前修正が必要」。監査のみ完了しており、上記の製品修正・公開は実施していない。
