const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const VERSION = 1;

function identity(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'ログインしてください。');
  const familyId = request.data?.familyId;
  if (typeof familyId !== 'string' || !familyId || familyId.includes('/')) {
    throw new HttpsError('invalid-argument', '家族情報が正しくありません。');
  }
  return {uid: request.auth.uid, familyId};
}
function activeMember(member) {
  if (!member.exists || member.get('status') !== 'active') {
    throw new HttpsError('permission-denied', '有効な家族メンバーだけが操作できます。');
  }
}
function adultMember(member) {
  activeMember(member);
  if (!['familyAdmin', 'parent'].includes(member.get('role'))) {
    throw new HttpsError('permission-denied', '保護者だけが操作できます。');
  }
}
function recentPassword(request) {
  const token = request.auth.token;
  const age = Math.floor(Date.now() / 1000) - token.auth_time;
  if (token.firebase?.sign_in_provider !== 'password' ||
      !Number.isFinite(age) || age < 0 || age > 300) {
    throw new HttpsError('failed-precondition', '保護者のパスワードを再入力してください。');
  }
}
function refs(db, familyId, uid) {
  return {
    member: db.doc(`families/${familyId}/members/${uid}`),
    access: db.doc(`families/${familyId}/chatAccess/${uid}`),
  };
}
exports.acknowledgeChatSafety = onCall(async request => {
  const {uid, familyId} = identity(request);
  if (request.data.version !== VERSION) throw new HttpsError('invalid-argument', '最新の安全案内を確認してください。');
  const db = getFirestore(), ref = refs(db, familyId, uid);
  await db.runTransaction(async tx => {
    activeMember(await tx.get(ref.member));
    tx.set(ref.access, {safetyVersion: VERSION, safetyAcceptedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
  return {version: VERSION};
});
exports.confirmAdultForChat = onCall(async request => {
  const {uid, familyId} = identity(request);
  recentPassword(request);
  if (request.data.adultDeclaration !== true || request.data.version !== VERSION) {
    throw new HttpsError('invalid-argument', '成人・保護者であることを確認してください。');
  }
  const db = getFirestore(), ref = refs(db, familyId, uid);
  await db.runTransaction(async tx => {
    adultMember(await tx.get(ref.member));
    tx.set(ref.access, {
      adultVersion: VERSION, adultConfirmedAt: FieldValue.serverTimestamp(),
      adultConfirmationMethod: 'password-reauth-and-18plus-declaration',
      adultAuthTime: request.auth.token.auth_time,
    }, {merge: true});
  });
  return {version: VERSION};
});
exports.setChildChatPermission = onCall(async request => {
  const {uid, familyId} = identity(request);
  recentPassword(request);
  const {childUserId, permission} = request.data;
  if (typeof childUserId !== 'string' || !childUserId || childUserId.includes('/') ||
      !['allowed', 'paused'].includes(permission)) {
    throw new HttpsError('invalid-argument', '利用設定が正しくありません。');
  }
  const db = getFirestore(), actor = refs(db, familyId, uid), child = refs(db, familyId, childUserId);
  await db.runTransaction(async tx => {
    const [member, adultAccess, target] = await Promise.all([tx.get(actor.member), tx.get(actor.access), tx.get(child.member)]);
    adultMember(member);
    if (adultAccess.get('adultVersion') !== VERSION || !target.exists || target.get('role') !== 'child') {
      throw new HttpsError('permission-denied', '成人確認を済ませた同じ家族の保護者だけが変更できます。');
    }
    tx.set(child.access, {
      permission, permissionVersion: VERSION, permissionUpdatedBy: uid,
      permissionUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.create(db.collection(`families/${familyId}/chatSafetyEvents`).doc(), {
      childUserId, permission, version: VERSION, changedBy: uid, changedAt: FieldValue.serverTimestamp(),
    });
  });
  return {permission};
});
