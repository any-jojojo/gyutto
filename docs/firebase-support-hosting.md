# 削除申請ページの公開・更新

Google の Firebase Hosting を採用。公開用の静的 HTML と CSS は `app/support-site/` に置く。ビルド、サーバー、データベースは不要。

公開URL: https://gyutto-cb454.web.app/ （2026-09-10 初回公開）

プライバシーポリシー: https://gyutto-cb454.web.app/privacy-policy （2026-09-11追加）

`app/support-site/privacy-policy.html` を編集する。Firebase HostingのcleanUrlsにより拡張子なしでアクセスできる。削除申請は引き続きルートURLで提供し、2ページを相互リンクする。Google Play Consoleのプライバシーポリシー欄には `/privacy-policy` のURL、アカウント削除のURL欄にはルートURLを登録する。

元文面は https://sites.google.com/view/gyutto-privacy-policy/ を確認し、現在未導入のAnalytics・Crashlyticsの説明を更新。運営者anyprogrammingと一般問い合わせ先anyprogramming@gmail.comを維持し、削除専用窓口gyutto.delete@gmail.comを明記した。元のGoogle Sitesページ自体とアプリ内のリンクは、このWebページ更新では変更していない。

## 更新方法

1. `app/support-site/index.html` の文言や `styles.css` の見た目を編集する。
2. `app` ディレクトリで `npm run deploy:support` を実行する。
3. 公開ページで内容とメール申請リンクを確認する。

Firebase CLI のログインが必要な場合は `npx firebase login` を実行する。認証情報をリポジトリに保存しない。

公開先は Firebase プロジェクト `gyutto-cb454` の既定 Hosting サイト。専用設定 `firebase.support.json` で Hosting のみを公開する。今後、同じ Hosting サイトを別用途で使う場合は、この設定による公開でサイト全体が置き換わることに注意する。

Hosting の無料枠はプロジェクト全体で共有される。Spark は無料枠超過時に制限され、Blaze は超過分が課金対象になる。契約プランはこの作業では変更しない。

申請の受付後は `account-deletion-operations.md` に従い、運営が本人確認と関連データの削除を行う。ページを公開するだけで削除処理が自動化されるわけではない。

旧 `gyutto-account-deletion` リポジトリは以前の Sites 版。Firebase 版の更新はこのリポジトリの `app/support-site/` を正とする。

公式資料:
- https://firebase.google.com/docs/hosting/quickstart
- https://firebase.google.com/docs/hosting/usage-quotas-pricing
