# App Overview

このドキュメントは、ぎゅっとアプリの全体像を整理するための設計書です。

## Concept

ぎゅっとは、家族だけで使うシンプルなチャットアプリです。

家族管理者が家族アカウントを作成し、親アカウントとこどもアカウントを追加します。家族メンバーがそろったら、全員が同じチャットを見て、メッセージを送受信できます。

LINE 連携や複数グループチャットは行わず、家族内の1つの共有チャットに集中します。

既存家族アカウントへの参加には招待コードを使います。親アカウントは初回ログイン時に本人がパスワードを設定し、こどもアカウントは家族管理者または親が初期パスワードを設定します。

ログインには Firebase Authentication を使います。初回リリースは Android を対象にし、その後 iOS 対応へ進みます。

## Target Users

| User | Description |
| --- | --- |
| 家族管理者 | 最初に家族アカウントを作成するユーザー |
| 親 | 家族管理者に追加される保護者ユーザー |
| こども | 家族管理者または親に追加される子どもユーザー |

## Roles

| Role | Can Create Family | Can Add Parent | Can Add Child | Can Chat | Can Read Messages |
| --- | --- | --- | --- | --- | --- |
| 家族管理者 | Yes | Yes | Yes | Yes | Yes |
| 親 | No | No | Yes | Yes | Yes |
| こども | No | No | No | Yes | Yes |

## Core Experience

1. 家族管理者がアプリを開始する
2. 家族管理者が家族アカウントを作成する
3. 家族管理者が親アカウントを追加する
4. 家族管理者または親がこどもアカウントを追加する
5. 家族メンバー全員が共有チャットを利用する
6. 各メッセージで誰が既読したか確認できる

## Account Setup

| Account | Setup Rule |
| --- | --- |
| 家族管理者 | 家族アカウント作成時に作成する |
| 親 | 招待コードで参加し、初回ログイン時に本人がパスワードを設定する |
| こども | 家族管理者または親が作成し、初期パスワードを設定する |

こどもアカウントにメールアドレスは必須にしません。

## Chat Model

ぎゅっとのチャットは、家族ごとに1つだけ存在します。

- 家族メンバー全員が同じチャットを見る
- 個別チャットは作らない
- グループチャット作成機能は作らない
- 家族外ユーザーとのチャットは作らない
- メッセージごとに既読者を記録する
- 既読者は常時表示する
- 送信済みメッセージの編集と削除は許可しない
- 画像送信は行わない

## MVP

初回リリースでは、次の状態を目指します。

- 家族アカウントを作成できる
- 親アカウントを追加できる
- こどもアカウントを追加できる
- 役割ごとに追加権限を制御できる
- 家族全員が共有チャットを利用できる
- メッセージごとの既読者を表示できる
- 招待コードで既存の家族アカウントへ参加できる
- 親は初回ログイン時に本人がパスワードを設定できる
- こどもはメールアドレスなしで利用開始できる
- Firebase Authentication でログインできる

## Not Included

初回リリースでは、次の機能は含めません。

- LINE 連携
- 複数グループチャット
- 家族外ユーザーとのチャット
- こどもによる家族メンバー追加
- こどもアカウントへのメールアドレス必須化
- メッセージ編集
- メッセージ削除
- チャットでの画像送信
- 初回リリースでの iOS 対応
- 初回リリースでの Web 対応
- 管理者向けダッシュボード
- 有料課金

## Technical Base

| Area | Choice |
| --- | --- |
| App framework | Flutter |
| Backend | Firebase |
| Authentication | Firebase Authentication |
| Project ID | `gyutto-cb454` |
| Repository | `any-jojojo/gyutto` |
| Main app directory | `app/` |
| Initial release | Android |
| Next release | iOS |

## Next Design Topics

次の設計書で詳細を固めます。

- `docs/user_flows.md`
- `docs/screen_list.md`
- `docs/data_model.md`
- `docs/firebase_design.md`
- `docs/auth_and_roles.md`
