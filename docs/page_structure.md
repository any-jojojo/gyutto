# Page Structure

このドキュメントは、ぎゅっとアプリのページ構成を整理するための一覧です。

実装時に迷わないように、現在実装済みのページと、MVPで今後作るページを分けて管理します。

## Page Map

```text
未ログイン
├─ トップ
│  ├─ ログイン
│  └─ 新規登録
│
ログイン後
├─ ログイン後トップ
│  ├─ 家族作成
│  ├─ 家族メンバー
│  │  ├─ 親アカウント追加
│  │  └─ こどもアカウント追加
│  ├─ 家族チャット
│  └─ アカウント設定
│
招待・参加
├─ 招待コード参加
├─ 親初回パスワード設定
├─ こどもQR参加確認
└─ こどもプロフィール編集
```

## Implemented Pages

| ID | Page | Route | File | Status |
| --- | --- | --- | --- | --- |
| PG-001 | トップ | `/` | `app/lib/features/home/home_screen.dart` | Done |
| PG-002 | ログイン / 新規登録 | `/login` | `app/lib/features/auth/presentation/login_screen.dart` | Done |
| PG-003 | ログイン後トップ | `/logged-in-home` | `app/lib/features/home/logged_in_home_screen.dart` | Done |

## MVP Pages To Build

| ID | Page | Route Candidate | Purpose | Main Users | Priority |
| --- | --- | --- | --- | --- | --- |
| PG-004 | 家族作成 | `/families/create` | 家族管理者が家族名と自分の表示名を登録する | 家族管理者 | Done |
| PG-005 | 招待コード参加 | `/invites/join` | 親が招待コードで家族に参加する | 親 | Must |
| PG-006 | 親初回パスワード設定 | `/parents/set-password` | 招待された親が初回パスワードを設定する | 親 | Must |
| PG-007 | 家族メンバー | `/family/members` | 家族メンバー一覧と役割を表示する | 全員 | Must |
| PG-008 | 親アカウント追加 | `/family/members/add-parent` | 家族管理者が親招待コードを発行する | 家族管理者 | Must |
| PG-009 | こどもアカウント追加 | `/family/members/add-child` | 管理者または親がこどもアカウントとQRを作る | 家族管理者, 親 | Must |
| PG-010 | こどもQR参加確認 | `/child/invite/confirm` | QRを読んだこどもが家族参加を確認する | こども | Must |
| PG-011 | こどもプロフィール編集 | `/child/profile/edit` | こどもが表示名を確認・変更する | こども | Must |
| PG-012 | 家族チャット | `/chat` | 家族全員が同じチャットを見る | 全員 | Must |
| PG-013 | アカウント設定 | `/account/settings` | 表示名、役割、ログアウトを扱う | 全員 | Should |
| PG-014 | こどもパスワード再設定リクエスト | `/child/password-reset/request` | こどもが親へ再設定許可を依頼する | こども | Should |
| PG-015 | パスワード再設定承認 | `/family/password-reset/requests` | 親または管理者が再設定リクエストを許可する | 家族管理者, 親 | Should |

## Navigation Rules

| Current State | Condition | Destination |
| --- | --- | --- |
| 未ログイン | アプリ起動 | トップ |
| 未ログイン | ログイン成功 | ログイン後トップ |
| 未ログイン | 新規登録成功 | ログイン後トップ |
| ログイン済み | 家族未作成 | 家族作成 |
| ログイン済み | 家族所属済み | ログイン後トップ |
| ログイン済み | 親初回設定が未完了 | 親初回パスワード設定 |
| こどもQRリンク | 有効なQRトークン | こどもQR参加確認 |
| 招待コード入力 | 有効な親招待コード | 親初回パスワード設定 |

## Role-Based Pages

| Page          | 家族管理者 | 親 | こども |
| ---           | ---       | --- | --- |
| ログイン後トップ | Yes        | Yes | Yes |
| 家族作成       | Yes       | No | No |
| 家族メンバー    | Yes      | Yes | Yes |
| 親アカウント追加 | Yes      | No | No |
| こどもアカウント追加 | Yes   | Yes | No |
| 家族チャット   | Yes | Yes | Yes |
| アカウント設定 | Yes | Yes | Yes |
| こどもパスワード再設定リクエスト | No | No | Yes |
| パスワード再設定承認 | Yes | Yes | No |

## Out Of Scope Pages

初回リリースでは、次のページは作りません。

- LINE連携
- 個別チャット
- 複数グループチャット
- 画像送信
- メッセージ編集
- メッセージ削除
- 課金
- 管理者向け分析ダッシュボード
