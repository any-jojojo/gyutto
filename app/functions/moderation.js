const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
function id(value) {
  if (typeof value !== 'string' || !value || value.length > 128 || value.includes('/')) {
    throw new HttpsError('invalid-argument', '対象が正しくありません。');
  }
  return value;
}
function actor(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'ログインしてください。');
  return {uid: request.auth.uid, familyId: id(request.data?.familyId)};
}
function requireMember(member) {
  if (!member.exists || member.get('status') !== 'active') {
    throw new HttpsError('permission-denied', '有効な家族メンバーだけが操作できます。');
  }
}
exports.acceptPostingTerms = onCall(async request => {
  const {uid, familyId} = actor(request);
  if (request.data.version !== 1 || request.data.accepted !== true) {
    throw new HttpsError('invalid-argument', '投稿規約への同意が必要です。');
  }
  const db = getFirestore();
  await db.runTransaction(async tx => {
    requireMember(await tx.get(db.doc(`families/${familyId}/members/${uid}`)));
    tx.set(db.doc(`families/${familyId}/chatAccess/${uid}`), {
      postingTermsVersion: 1, postingTermsAcceptedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
  return {version: 1};
});
exports.reportChatAbuse = onCall(async request => {
  const {uid, familyId} = actor(request);
  const {kind, reason, details = ''} = request.data;
  const targetId = id(request.data.targetId);
  if (!['message', 'user'].includes(kind) ||
      !['bullying', 'sexual', 'violence', 'personalInfo', 'other'].includes(reason) ||
      typeof details !== 'string' || details.length > 1000) {
    throw new HttpsError('invalid-argument', '通報内容を確認してください。');
  }
  const db = getFirestore(), report = db.collection('moderationReports').doc();
  await db.runTransaction(async tx => {
    const base = `families/${familyId}`;
    const limitRef = db.doc(`moderationReportLimits/${uid}`);
    const [member, target, limit] = await Promise.all([
      tx.get(db.doc(`${base}/members/${uid}`)),
      tx.get(db.doc(`${base}/${kind === 'message' ? 'messages' : 'members'}/${targetId}`)),
      tx.get(limitRef),
    ]);
    requireMember(member);
    if (!target.exists) throw new HttpsError('not-found', '通報対象が見つかりません。');
    const targetUserId = kind === 'message' ? target.get('senderUserId') : targetId;
    if (targetUserId === uid) throw new HttpsError('invalid-argument', '自分自身は通報できません。');
    const now = Date.now();
    if (limit.exists && now - limit.get('lastAt').toMillis() < 30000) {
      throw new HttpsError('resource-exhausted', '30秒ほど待ってから送信してください。');
    }
    tx.create(report, {
      familyId, reporterUserId: uid, targetUserId, targetId, kind, reason, details,
      evidence: kind === 'message' ? {text: target.get('text'), senderUserId: targetUserId} : null,
      status: 'new', createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(limitRef, {lastAt: Timestamp.fromMillis(now)});
  });
  return {reportId: report.id};
});
