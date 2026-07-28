# Data Model

このドキュメントは、ぎゅっとアプリで扱うデータ構造を整理するための設計書です。

Firebase Authentication と Cloud Firestore を前提にします。

## Overview

ぎゅっとは、家族ごとに1つの共有チャットを持ちます。

主なデータは次の単位で管理します。

- ユーザー
- 家族
- 家族メンバー
- 招待
- メッセージ
- 既読
- パスワード再設定リクエスト

## Collections

```text
users/{userId}
families/{familyId}
families/{familyId}/members/{memberId}
families/{familyId}/invites/{inviteId}
families/{familyId}/messages/{messageId}
families/{familyId}/passwordResetRequests/{requestId}
```

## users

Firebase Authentication のユーザーに対応するプロフィール情報を保存します。

Path:

```text
users/{userId}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| displayName | string | Yes | アプリ内表示名 |
| familyId | string | Yes | 所属家族ID |
| role | string | Yes | `familyAdmin`, `parent`, `child` |
| email | string | No | メールアドレス。こどもは必須にしない |
| createdAt | timestamp | Yes | 作成日時 |
| updatedAt | timestamp | Yes | 更新日時 |

Notes:

- `userId` は Firebase Authentication の `uid` を使う
- こどもアカウントはメールアドレスなしでも作成できる
- 1ユーザーは MVP では1家族に所属する

## families

家族アカウント本体を保存します。

Path:

```text
families/{familyId}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| name | string | Yes | 家族名 |
| adminUserId | string | Yes | 家族管理者の userId |
| createdAt | timestamp | Yes | 作成日時 |
| updatedAt | timestamp | Yes | 更新日時 |

Notes:

- 家族ごとに1つの共有チャットを持つ
- 複数グループチャットは作らない

## members

家族に所属するメンバー情報を保存します。

Path:

```text
families/{familyId}/members/{memberId}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| userId | string | Yes | Firebase Authentication の uid |
| displayName | string | Yes | 家族内の表示名 |
| role | string | Yes | `familyAdmin`, `parent`, `child` |
| status | string | Yes | `active`, `invited`, `disabled` |
| createdBy | string | Yes | 作成した userId |
| createdAt | timestamp | Yes | 作成日時 |
| updatedAt | timestamp | Yes | 更新日時 |

Role rules:

| Role | Can Add Parent | Can Add Child |
| --- | --- | --- |
| familyAdmin | Yes | Yes |
| parent | No | Yes |
| child | No | No |

## invites

親招待コードとこども用 QR コードの招待情報を保存します。

Path:

```text
families/{familyId}/invites/{inviteId}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| type | string | Yes | `parentInvite`, `childQrInvite` |
| tokenHash | string | Yes | 招待コードまたはQR用トークンのハッシュ値 |
| targetRole | string | Yes | `parent` または `child` |
| targetMemberId | string | No | こどもなど、事前作成済みメンバーがある場合の memberId |
| createdBy | string | Yes | 招待を作成した userId |
| expiresAt | timestamp | Yes | 有効期限 |
| usedAt | timestamp | No | 使用日時 |
| usedBy | string | No | 使用した userId |
| status | string | Yes | `active`, `used`, `expired`, `revoked` |
| createdAt | timestamp | Yes | 作成日時 |

Rules:

- 有効期限は1時間
- 有効期限内は `あと1時間有効  2026/07/29 18:00まで` の形式で表示する
- 期限切れ時は `有効期限が切れました。再発行してください。` と表示する
- 親招待コードとこども用 QR コードは同じ有効期限表示を使う
- 招待コードや QR トークンは Firestore に平文保存しない
- Firestore にはハッシュ化した `tokenHash` を保存する
- QR コードには招待リンクを埋め込み、リンク内のトークンを照合して参加処理を行う

## Child Sign-In

こどもアカウントは、QR コードを使って参加を開始します。

Flow:

```text
親または家族管理者がこどもアカウントを作成
↓
初期パスワードを設定
↓
招待リンクを含む QR コードを表示
↓
こどもが自分のスマホで QR コードを読み取る
↓
招待リンクのトークンを検証
↓
こどもが家族参加を確認
↓
表示名を確認・変更
↓
Firebase Authentication のこどもアカウントでログイン状態にする
```

Notes:

- QR コードはアプリ上の参加導線として使う
- Firebase Authentication の標準プロバイダとして QR コードを使うわけではない
- QR トークンは1時間で期限切れにする
- QR トークンはハッシュ化して保存する
- こどもアカウントにメールアドレスは必須にしない

## messages

家族共有チャットのメッセージを保存します。

Path:

```text
families/{familyId}/messages/{messageId}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| senderUserId | string | Yes | 送信者 userId |
| senderDisplayName | string | Yes | 送信時点の表示名 |
| text | string | Yes | メッセージ本文 |
| readBy | map | Yes | 既読者情報 |
| createdAt | timestamp | Yes | 送信日時 |

readBy:

```text
readBy: {
  "{userId}": {
    "displayName": "string",
    "readAt": "timestamp"
  }
}
```

Rules:

- メッセージはテキストのみ
- 画像送信は行わない
- メッセージ編集は許可しない
- メッセージ削除は許可しない
- 既読者はメッセージごとに常時表示する

## passwordResetRequests

こどもアカウントのパスワード再設定リクエストを保存します。

Path:

```text
families/{familyId}/passwordResetRequests/{requestId}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| childUserId | string | Yes | 再設定を依頼したこどもの userId |
| requestedBy | string | Yes | リクエスト送信者 userId |
| approvedBy | string | No | 許可した親または家族管理者の userId |
| status | string | Yes | `pending`, `approved`, `rejected`, `completed`, `expired` |
| createdAt | timestamp | Yes | 作成日時 |
| approvedAt | timestamp | No | 許可日時 |
| completedAt | timestamp | No | 再設定完了日時 |

Rules:

- こどもは親へパスワード再設定リクエストを送信できる
- 親または家族管理者が許可した場合のみ再設定できる
- 親が許可しない場合、再設定は行わない

## Role Values

| Value | Label |
| --- | --- |
| familyAdmin | 家族管理者 |
| parent | 親 |
| child | こども |

## Status Values

| Field | Values |
| --- | --- |
| member.status | `active`, `invited`, `disabled` |
| invite.status | `active`, `used`, `expired`, `revoked` |
| passwordResetRequest.status | `pending`, `approved`, `rejected`, `completed`, `expired` |

## Security Notes

- 家族外ユーザーは `families/{familyId}` 配下のデータを読めない
- `child` は親アカウントやこどもアカウントを追加できない
- `parent` は親アカウントを追加できない
- `familyAdmin` は親アカウントとこどもアカウントを追加できる
- `parent` はこどもアカウントを追加できる
- メッセージの更新と削除は許可しない
