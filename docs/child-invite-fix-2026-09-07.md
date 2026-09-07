# こども招待の期限と同時消費を必須化

Firestoreルールの共通関数 isConsumingChildInvite を、joinRequests 作成、招待更新、トークン更新から使用する。

- 招待とトークンの型・対象役割・familyId・inviteId・tokenHashの対応を検証。
- 両方の expiresAt が timestamp で、サーバーの request.time より未来かつ一致することを必須化。
- 操作前は両方 active、getAfter による操作後は両方 used を必須化。
- 招待の usedBy と申請者 userId が認証ユーザーに一致することを検証。
- 同じ操作で新しい pending / child の申請が作成されることを必須化。既存申請を使った消費は拒否。
- affectedKeys で招待は status/usedAt/usedBy、トークンは status だけの変更に限定。
- 家族メンバーによる招待更新も共通検証を通し、招待だけを消費する迂回を拒否。

トークンには現行アプリどおり status のみを書き込む。usedBy の照合対象は招待ドキュメント。Flutter側の参加バッチは変更不要。

## 検証結果

ローカルFirestore Emulatorで実施。

- こども招待27ケース成功。正常な4ドキュメントの参加バッチ、再利用拒否、期限切れ、不完全なバッチ、usedByの不一致、参照先や型の改ざん、自己承認などを検証。拒否時に申請や消費が部分的に保存されないことも確認。
- 親招待26ケース成功。
- 既存Firestoreルールテスト成功。
- 全体監査31項目すべて成功。前回残っていた期限切れ申請・未消費トークンによる複数申請の3項目も拒否を確認。

再実行は app/ で npm.cmd run test:rules:child-invite。
本番へのデプロイは未実施。この結果はリポジトリ内ルールを対象としたものであり、システム全体の安全性を保証するものではない。
