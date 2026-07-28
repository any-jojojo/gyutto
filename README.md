# gyutto

ぎゅっとは、Flutter と Firebase を土台に開発する、独立した家族専用チャットアプリです。

家族管理者が家族アカウントを作成し、親アカウントとこどもアカウントを追加します。家族メンバーは、全員が同じ共有チャットを利用できます。

このリポジトリでは、Flutter アプリ本体、設計書、共通アセット、スクリーンショット、補助スクリプトをまとめて管理します。

## Directory Structure

```text
gyutto/
├── app/          # Flutter project
├── docs/         # Design documents
├── assets/       # Shared assets
├── figma/        # Figma exports and references
├── screenshots/  # Development and release screenshots
├── scripts/      # Utility scripts
└── README.md
```

## App

Flutter プロジェクトは `app/` にあります。

```powershell
cd app
flutter run
```

## Current Setup

- Flutter project: created in `app/`
- Firebase project: `gyutto-cb454`
- Firebase configuration: generated with FlutterFire CLI
- GitHub repository: `https://github.com/any-jojojo/gyutto.git`
- Default branch: `main`
- Initial release target: Android
- Next release target: iOS

## Product Decisions

- LINE 連携は行わない
- 家族ごとに1つの共有チャットを持つ
- 役割は `家族管理者`、`親`、`こども` とする
- Firebase Authentication を使う
- 既存家族アカウントへの参加は招待コードを使う
- 親アカウントは初回ログイン時に本人がパスワードを設定する
- こどもアカウントは家族管理者または親が初期パスワードを設定する
- こどもアカウントにメールアドレスは必須にしない
- 家族管理者は親アカウントを追加できる
- 家族管理者と親はこどもアカウントを追加できる
- 既読者はメッセージ上に常時表示する
- メッセージの編集と削除は許可しない
- チャットで画像送信は行わない

## Development Flow

このプロジェクトは、1ファイルずつ確認しながら進めます。

```text
1. Create or update one file
2. Run checks
3. Review
4. Approved
5. Git commit
6. Move to the next file
```

`Approved` が出るまでは commit しません。

## Checks

Flutter 側の基本確認は `app/` で実行します。

```powershell
cd app
flutter analyze
flutter test
```

## Notes

Windows で Firebase プラグインを含む Flutter アプリを実行する場合、Developer Mode が必要になることがあります。
