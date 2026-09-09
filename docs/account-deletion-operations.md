# アカウント削除の受付運用（今回リリース）

受付先：anyprogramming@gmail.com
申請ページ：https://gyutto-account-deletion.any-jojojo.chatgpt.site/
サイトのソース：C:/Users/any/Development/gyutto-account-deletion

今回の機能はメール申請の窓口です。メール送信、アカウント削除、データ削除を自動実行するものではありません。
ページに記載した「本人確認後、原則30日以内に削除」「対応メールは完了後30日以内に受付メールボックスから削除」は公開前に運営者の確認が必要です。

## 受付と本人確認

1. メールを確認し、対象 UID・家族・本人または保護者の申請権限を特定します。表示名だけで本人と判断せず、登録済み連絡先への確認や既存の保護者との関係確認を行います。パスワードや招待コードを要求しません。
2. 家族管理者の場合、残る家族の管理権限をどう引き継ぐか確認します。ほかの家族のアカウントや投稿を本人の申請だけで削除しません。
3. 削除対象を一覧にし、削除担当者が対象 UID と影響範囲を確認してから実行します。

## データ削除担当者の確認対象

- Firebase Authentication の対象ユーザーと有効セッション。
- users/{uid} と families/{familyId}/members/{uid}。
- families 配下 messages の本人の投稿（senderUserId）と、他者投稿内の本人の readBy エントリ。
- families 配下 invites / joinRequests / passwordResetRequests に含まれる本人情報。createdBy・userId・childUserId・requestedBy・approvedBy などの参照も確認。
- parentInviteCodes / childInviteTokens の対応する招待情報。
- families の createdBy などの本人参照。残る管理者との関係やアプリ動作を確認して更新。
- ユーザーが過去に所属・申請した別の家族も対象に含め、現在の familyId だけで調査を終えない。

Firestore の親ドキュメント削除ではサブコレクションは消えません。Authentication のユーザー削除だけでも関連データは消えません。管理者用の権限で関連データまで処理し、クライアント向けのセキュリティルールを緩めないでください。

## 完了確認

対象ユーザーで再ログインできないこと、関連データが残っていないこと、残る家族の権限が正しいことを確認し、本人に完了を連絡します。法令上の保持やバックアップ等で即時に削除できない情報があれば、実際の対象・理由・期間を確定して申請ページにも反映します。対応メールは承認した保持期限に従い削除します。

## 次回リリース

アプリ内で本人確認と申請が完結する仕組みを追加します。今回はアプリの設定から上記 Web ページへ移動します。