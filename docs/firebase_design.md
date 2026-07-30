# Firebase Design

このドキュメントは、ぎゅっとアプリで Firebase をどのように使うかを整理するための設計書です。

初回リリースは Android を対象にします。

## Firebase Project

| Item | Value |
| --- | --- |
| Firebase Project ID | `gyutto-cb454` |
| Flutter app directory | `app/` |
| Android package name | `com.example.gyutto` |
| iOS bundle ID | `com.example.gyutto` |
| Initial release | Android |
| Next release | iOS |

## Firebase Services

MVP で使用する Firebase サービスは次の通りです。

| Service | Usage | MVP |
| --- | --- | --- |
| Firebase Authentication | ログイン、家族管理者・親・こどもアカウントの認証 | Yes |
| Cloud Firestore | 家族、メンバー、招待、チャット、既読、再設定リクエストの保存 | Yes |
| Cloud Functions | 招待トークン検証、ハッシュ処理、権限が必要な処理 | Should |
| Firebase Hosting | Web リリース時に検討 | No |
| Cloud Storage | 画像送信を行わないため初回リリースでは使わない | No |
| Firebase Cloud Messaging | 通知機能を入れる場合に検討 | No |

## Authentication

Firebase Authentication を使います。

### Account Types

| Role | Auth Approach |
| --- | --- |
| 家族管理者 | Firebase Authentication で通常作成 |
| 親 | 招待コード参加後、初回ログイン時に本人がパスワード設定 |
| こども | QR コードから参加し、Cloud Functions で検証後に Custom Token Auth でログインする |

### Child Account Notes

- こどもアカウントにメールアドレスは必須にしない
- QR コードは Firebase Authentication の標準プロバイダではなく、アプリ上の参加導線として扱う
- QR の招待トークンと初期パスワードを Cloud Functions で検証する
- 検証後、Firebase Admin SDK で Custom Token を発行する
- アプリは Custom Token を使って Firebase Authentication にログインする

## Firestore Structure

Firestore の基本構造は `docs/data_model.md` に合わせます。

```text
users/{userId}
families/{familyId}
families/{familyId}/members/{memberId}
families/{familyId}/invites/{inviteId}
families/{familyId}/messages/{messageId}
families/{familyId}/passwordResetRequests/{requestId}
```

## Invite Design

親招待コードとこども用 QR コードは、どちらも `families/{familyId}/invites/{inviteId}` に保存します。

### Rules

- 有効期限は1時間
- Firestore に招待コードや QR トークンを平文保存しない
- Firestore には `tokenHash` を保存する
- アプリまたは Cloud Functions 側で受け取ったトークンをハッシュ化して照合する
- 期限切れ時は `有効期限が切れました。再発行してください。` と表示する

### Display

有効期限内:

```text
あと1時間有効  2026/07/29 18:00まで
```

有効期限切れ:

```text
有効期限が切れました。再発行してください。
```

## Chat Design

家族ごとに1つの共有チャットを持ちます。

### Rules

- 家族メンバー全員が同じチャットを見る
- 個別チャットは作らない
- 複数グループチャットは作らない
- 家族外ユーザーとのチャットは作らない
- メッセージはテキストのみ
- 画像送信は行わない
- メッセージ編集は許可しない
- メッセージ削除は許可しない

### Read Receipts

既読はメッセージ単位で `readBy` に保存します。

```text
readBy: {
  "{userId}": {
    "displayName": "string",
    "readAt": "timestamp"
  }
}
```

既読者はメッセージ上に常時表示します。

## Password Reset Design

こどもアカウントのパスワード再設定は、親の許可を必要とします。

Flow:

```text
こどもがパスワード再設定をリクエスト
↓
passwordResetRequests に pending で保存
↓
親または家族管理者が確認
↓
許可した場合 approved に更新
↓
こどもが新しいパスワードを設定
↓
completed に更新
```

親が許可しない場合、再設定は行いません。

## Security Rules Policy

Firestore Security Rules では、最低限次を満たします。

### Users

- ログインユーザーは自分の `users/{userId}` を読める
- 家族メンバーは同じ家族のメンバー表示に必要なユーザー情報を読める
- 自分以外のユーザー情報を自由に更新できない

### Families

- 家族メンバーだけが自分の `families/{familyId}` を読める
- 家族作成はログイン済みユーザーだけが行える
- 家族外ユーザーは読めない

### Members

- 家族メンバーだけが `members` を読める
- `familyAdmin` は親とこどもを追加できる
- `parent` はこどもを追加できる
- `child` はメンバーを追加できない

### Invites

- 招待作成は `familyAdmin` または許可された `parent` のみ
- 親招待は `familyAdmin` のみ作成できる
- こども用 QR 招待は `familyAdmin` または `parent` が作成できる
- 招待トークンの平文は保存しない
- 期限切れ招待は使用できない

### Messages

- 家族メンバーだけがメッセージを読める
- 家族メンバーだけがテキストメッセージを作成できる
- メッセージ本文の更新は許可しない
- メッセージ削除は許可しない
- 既読情報は本人分のみ追加・更新できる

### Password Reset Requests

- こどもは自分のパスワード再設定リクエストを作成できる
- 親または家族管理者は同じ家族のリクエストを確認できる
- 親または家族管理者だけが `approved` または `rejected` に更新できる
- 許可されていないリクエストでは再設定できない

## Cloud Functions Strategy

Cloud Functions 方針は `Hybrid` を採用します。

進め方:

1. Flutter 側で画面と状態遷移を先に作る
2. 招待作成、QR検証、こどもアカウント作成は Cloud Functions で実装する
3. 親承認パスワード再設定は、MVP中盤で Cloud Functions に寄せる

理由:

- 最初からすべてを Cloud Functions に寄せるより画面開発を止めにくい
- 招待トークンやこどもアカウント作成など、危険な処理はクライアントに置かずに済む
- 将来の Android リリース前にセキュリティ境界を固めやすい

## Recommended Cloud Functions

MVP では、次の処理を Cloud Functions に寄せます。

| Function | Purpose |
| --- | --- |
| createInvite | 招待コード/QRトークンを生成し、ハッシュだけ保存する |
| validateInvite | 受け取ったトークンをハッシュ照合し、有効期限と状態を確認する |
| createChildAccount | こどもアカウント作成を安全に行う |
| approveChildPasswordReset | 親の許可処理を行う |

理由:

- 招待トークンをクライアントだけで扱うより安全
- 権限チェックをサーバー側に集約できる
- こどもアカウント作成のルールを一箇所にまとめられる

## Cloud Functions Specifications

Cloud Functions は HTTPS Callable Functions として実装します。

Callable Functions を使う理由:

- Flutter アプリから直接呼び出しやすい
- Firebase Authentication の認証情報をリクエストに含められる
- 権限チェックをサーバー側で行いやすい

### Common Rules

全関数で共通するルールです。

- 未ログインユーザーからの呼び出しは拒否する
- 呼び出し元の `uid` を Firebase Authentication から取得する
- 呼び出し元の `users/{userId}` と `families/{familyId}/members/{memberId}` を確認する
- `serverTimestamp` を使って時刻を保存する
- 招待コードや QR トークンは平文保存しない
- クライアントへ返す平文トークンは作成直後の1回だけにする

共通エラー:

| Code | Meaning |
| --- | --- |
| unauthenticated | ログインしていない |
| permission-denied | 権限がない |
| invalid-argument | 入力値が不正 |
| not-found | 対象データが存在しない |
| failed-precondition | 状態が処理条件を満たさない |
| internal | 予期しないサーバーエラー |

### createInvite

親招待コードまたはこども用 QR トークンを作成します。

Callable name:

```text
createInvite
```

Input:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| familyId | string | Yes | 対象家族ID |
| type | string | Yes | `parentInvite` または `childQrInvite` |
| targetMemberId | string | No | こども用 QR の場合、事前作成済み memberId |

Permission:

| Type | Allowed Caller |
| --- | --- |
| parentInvite | `familyAdmin` |
| childQrInvite | `familyAdmin`, `parent` |

Process:

```text
呼び出し元のログイン確認
↓
呼び出し元が familyId のメンバーか確認
↓
type ごとの権限確認
↓
ランダムな招待トークンを生成
↓
トークンをハッシュ化
↓
expiresAt = now + 1 hour を設定
↓
families/{familyId}/invites/{inviteId} を作成
↓
平文トークンまたは招待URLを返す
```

Firestore write:

```text
families/{familyId}/invites/{inviteId}
```

Response:

| Field | Type | Description |
| --- | --- | --- |
| inviteId | string | 作成した inviteId |
| inviteUrl | string | QRコード化または共有に使うURL |
| token | string | 作成直後のみ返す平文トークン |
| expiresAt | timestamp | 有効期限 |

Notes:

- `token` は Firestore に保存しない
- `tokenHash` のみ保存する
- こども用 QR コードは `inviteUrl` を QR 化して表示する
- 有効期限は1時間

### validateInvite

招待コードまたは QR トークンを検証します。

Callable name:

```text
validateInvite
```

Input:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| familyId | string | Yes | 対象家族ID |
| token | string | Yes | 招待コードまたは QR トークン |

Permission:

- 親招待コードの検証は未参加ユーザーでも使うため、未ログイン呼び出しを許可するか検討が必要
- こども用 QR は参加導線のため、未ログイン状態から呼び出せる必要がある

Process:

```text
token をハッシュ化
↓
families/{familyId}/invites から tokenHash 一致の active invite を検索
↓
expiresAt を確認
↓
used/revoked でないことを確認
↓
招待タイプと対象ロールを返す
```

Response:

| Field | Type | Description |
| --- | --- | --- |
| inviteId | string | 対象 inviteId |
| familyId | string | 対象 familyId |
| familyName | string | 表示用家族名 |
| type | string | `parentInvite` または `childQrInvite` |
| targetRole | string | `parent` または `child` |
| targetMemberId | string | 対象 memberId |
| expiresAt | timestamp | 有効期限 |

Errors:

| Case | Code |
| --- | --- |
| token が不正 | invalid-argument |
| invite が存在しない | not-found |
| 期限切れ | failed-precondition |
| 使用済み | failed-precondition |

Open point:

- 未ログイン状態から呼び出すため、App Check の導入を検討する

### createChildAccount

こども用 QR トークンと初期パスワードを検証し、こどもアカウントを Firebase Authentication 上でログイン可能にします。

Callable name:

```text
createChildAccount
```

Input:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| familyId | string | Yes | 対象家族ID |
| inviteToken | string | Yes | QR から取得したトークン |
| initialPassword | string | Yes | 親または家族管理者が設定した初期パスワード |
| displayName | string | Yes | こどもの表示名 |

Permission:

- QR トークンと初期パスワードを知っているこどもだけが実行できる
- 未ログイン状態から呼び出す可能性がある

Process:

```text
inviteToken をハッシュ化
↓
childQrInvite を検証
↓
targetMemberId の member を取得
↓
初期パスワードを検証
↓
Firebase Admin SDK でこども用 Auth user を作成または取得
↓
users/{childUserId} を作成/更新
↓
members/{memberId} を active に更新
↓
invite を used に更新
↓
Custom Token を発行
↓
Custom Token を返す
```

Firestore writes:

```text
users/{childUserId}
families/{familyId}/members/{memberId}
families/{familyId}/invites/{inviteId}
```

Response:

| Field | Type | Description |
| --- | --- | --- |
| customToken | string | Firebase Authentication ログイン用 Custom Token |
| userId | string | こどもの userId |
| familyId | string | 所属 familyId |
| role | string | `child` |

Important:

- 初期パスワードは平文保存しない
- 初期パスワードを保存する場合はハッシュ化する
- Custom Token は短時間で使い切る前提
- QR トークンは1回使用したら `used` にする

### approveChildPasswordReset

こどもアカウントのパスワード再設定リクエストを親または家族管理者が許可します。

Callable name:

```text
approveChildPasswordReset
```

Input:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| familyId | string | Yes | 対象家族ID |
| requestId | string | Yes | passwordResetRequests のID |
| approve | boolean | Yes | 許可する場合 true、拒否する場合 false |

Permission:

- `familyAdmin`
- `parent`
- 同じ家族のリクエストのみ処理できる

Process:

```text
呼び出し元のログイン確認
↓
呼び出し元が familyAdmin または parent か確認
↓
passwordResetRequests/{requestId} を取得
↓
status が pending であることを確認
↓
approve=true なら approved に更新
↓
approve=false なら rejected に更新
```

Firestore write:

```text
families/{familyId}/passwordResetRequests/{requestId}
```

Response:

| Field | Type | Description |
| --- | --- | --- |
| requestId | string | 処理した requestId |
| status | string | `approved` または `rejected` |
| approvedBy | string | 処理した userId |

Notes:

- 実際の新パスワード設定処理は別関数に分ける可能性がある
- MVP では `approved` 状態を見て、こどもが新しいパスワード設定画面へ進む

## Indexes

初期想定の Firestore クエリです。

| Collection | Query | Index |
| --- | --- | --- |
| `families/{familyId}/messages` | `orderBy(createdAt desc)` | Single field |
| `families/{familyId}/invites` | `where(status == active), where(expiresAt > now)` | Composite may be required |
| `families/{familyId}/passwordResetRequests` | `where(status == pending), orderBy(createdAt desc)` | Composite may be required |
| `families/{familyId}/members` | `where(role == child), orderBy(createdAt desc)` | Composite may be required |

## Environment and Config

FlutterFire CLI で生成済みです。

```text
app/lib/firebase_options.dart
app/firebase.json
app/android/app/google-services.json
```

iOS 対応時は、必要に応じて iOS 側の Firebase 設定ファイルを再確認します。

## Out of Scope for MVP

- Cloud Storage を使った画像送信
- Firebase Hosting による Web 公開
- Firebase Cloud Messaging による通知
- 複数グループチャット
- メッセージ編集
- メッセージ削除

## Child Authentication Options

こどもアカウントは QR コードから参加を開始します。

ただし、QR コード自体は Firebase Authentication の標準サインインプロバイダではありません。QR コードで招待リンクを開き、その後どの Firebase Authentication 方式でログイン状態にするかを決めます。

Firebase Authentication は、メール/パスワード、電話番号、Google などのプロバイダ、匿名認証、カスタム認証システムとの連携に対応しています。

| Option | Description | Pros | Cons |
| --- | --- | --- | --- |
| Email/Password with generated child email | こども用に内部メール形式のIDを生成し、親が設定した初期パスワードでログインする | Firebase Authentication の標準機能だけで実装しやすい。パスワード変更も扱いやすい | 実在しないメール形式を設計する必要がある。メールアドレス不要という仕様と見た目が少しずれる |
| Anonymous Auth + family member profile | QR参加後に匿名認証でログインし、Firestore の member 情報でこどもとして扱う | メールアドレス不要。導入が比較的簡単 | 端末変更や再ログインに弱い。長期利用するこどもアカウントには不安が残る |
| Custom Token Auth with Cloud Functions | QRトークンと初期パスワードを Cloud Functions で検証し、Admin SDK でカスタムトークンを発行してログインする | メール不要。QR招待、初期パスワード、親承認をサーバー側で安全に制御しやすい | Cloud Functions 実装が必要。MVPの初期工数が増える |
| Phone Auth | こどもの電話番号にSMSを送ってログインする | Firebase Authentication の標準機能。本人確認が強い | こどもに電話番号が必要。家族向けMVPには重い |

### Child Authentication Decision Points

| Question | Why It Matters |
| --- | --- |
| こどもが端末変更したときに再ログインできる必要があるか | Anonymous Auth では弱く、Custom Token か Email/Password が向く |
| メールアドレス不要の体験をどこまで守るか | Email/Password は内部メールID設計が必要 |
| MVPで Cloud Functions を許容するか | Custom Token Auth は Cloud Functions 前提になる |
| パスワード再設定を親承認にしたいか | Custom Token Auth が最も制御しやすい |

### Decision

こどもアカウントの認証方式は `Custom Token Auth with Cloud Functions` を採用します。

理由:

- こどもにメールアドレスを必須にしない方針と相性が良い
- QRトークンをハッシュ化して扱いやすい
- 親が設定した初期パスワードと親承認の再設定フローをサーバー側で制御できる
- Firestore Security Rules と Cloud Functions の役割分担が明確になる

比較のため他方式も残しますが、実装方針は Custom Token Auth を前提にします。

## Cloud Functions Options

Cloud Functions を MVP から使うか、最初はクライアント実装で進めるかを比較します。

Firebase の callable functions は、アプリから直接呼び出せるサーバー関数です。呼び出し時には Firebase Authentication トークンなどが自動的に含まれるため、権限が必要な処理と相性が良いです。

| Option | Description | Pros | Cons |
| --- | --- | --- | --- |
| Use Cloud Functions from MVP | 招待作成、QR検証、こどもアカウント作成、親承認をサーバー側で処理する | セキュリティを作りやすい。トークンのハッシュ化や権限チェックを集約できる。後から作り直す範囲が小さい | 初期実装とデプロイ設定が増える。Functions の検証も必要 |
| Client-first implementation | Flutter アプリと Firestore Security Rules を中心に実装する | 初期画面を早く作れる。MVPの見た目確認が進めやすい | 招待トークン、こどもアカウント作成、親承認の安全性を保つのが難しい。後で Functions に移す可能性が高い |
| Hybrid | 画面は先にクライアントで作り、危険な処理だけ Functions にする | 速度と安全性のバランスが良い。招待/認証だけ堅くできる | 境界設計が必要。クライアント処理と Functions 処理が混在する |

### Recommended Function Boundaries

MVP で Cloud Functions を使う場合、まずは次に絞ります。

| Function | MVP Need | Reason |
| --- | --- | --- |
| createInvite | High | 招待コード/QRトークンを平文保存せず、ハッシュ保存するため |
| validateInvite | High | 期限切れ、使用済み、改ざんをサーバー側で確認するため |
| createChildAccount | High | こどもアカウントをメール不要で安全に作るため |
| approveChildPasswordReset | Medium | 親承認フローを改ざんされにくくするため |

### Cloud Functions Decision Points

| Question | Cloud Functions Favored When |
| --- | --- |
| 招待コード/QRトークンを安全に扱いたいか | Yes |
| こどもアカウントをメール不要で作りたいか | Yes |
| 親承認なしの再設定を確実に防ぎたいか | Yes |
| まず画面だけ早く触りたいか | No。クライアント先行も候補 |

### Decision

ぎゅっとでは、Cloud Functions 方針として `Hybrid` を採用します。

進め方:

1. Flutter 側で画面と状態遷移を先に作る
2. 招待作成、QR検証、こどもアカウント作成は Cloud Functions で実装する
3. 親承認パスワード再設定は、MVP中盤で Cloud Functions に寄せる

理由:

- 最初からすべてを Cloud Functions に寄せるより画面開発を止めにくい
- 招待トークンやこどもアカウント作成など、危険な処理はクライアントに置かずに済む
- 将来の Android リリース前にセキュリティ境界を固めやすい
