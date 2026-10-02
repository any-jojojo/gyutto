const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

initializeApp();

exports.reviewChildJoinRequest = onCall(async (request) => {
  const reviewerId = request.auth?.uid;
  if (!reviewerId) {
    throw new HttpsError('unauthenticated', 'ログインが必要です。');
  }

  const familyId = request.data?.familyId;
  const childUserId = request.data?.userId;
  const decision = request.data?.decision;
  if (
    typeof familyId !== 'string' ||
    familyId.length === 0 ||
    typeof childUserId !== 'string' ||
    childUserId.length === 0 ||
    !['approved', 'rejected'].includes(decision)
  ) {
    throw new HttpsError('invalid-argument', '申請情報が正しくありません。');
  }

  const db = getFirestore();
  const reviewerRef = db.doc(`families/${familyId}/members/${reviewerId}`);
  const requestRef = db.doc(
    `families/${familyId}/joinRequests/${childUserId}`,
  );
  const memberRef = db.doc(`families/${familyId}/members/${childUserId}`);
  const userRef = db.doc(`users/${childUserId}`);

  await db.runTransaction(async (transaction) => {
    const [reviewerSnapshot, joinRequestSnapshot] = await Promise.all([
      transaction.get(reviewerRef),
      transaction.get(requestRef),
    ]);

    if (
      !reviewerSnapshot.exists ||
      !['familyAdmin', 'parent'].includes(reviewerSnapshot.get('role')) ||
      reviewerSnapshot.get('status') !== 'active'
    ) {
      throw new HttpsError(
        'permission-denied',
        '家族管理者または親だけが申請を処理できます。',
      );
    }
    if (
      !joinRequestSnapshot.exists ||
      joinRequestSnapshot.get('status') !== 'pending' ||
      joinRequestSnapshot.get('role') !== 'child' ||
      joinRequestSnapshot.get('userId') !== childUserId
    ) {
      throw new HttpsError('failed-precondition', '処理可能な申請がありません。');
    }

    const now = FieldValue.serverTimestamp();
    transaction.update(requestRef, {
      status: decision,
      reviewedAt: now,
      reviewedBy: reviewerId,
    });

    if (decision === 'approved') {
      transaction.create(memberRef, {
        userId: childUserId,
        displayName: joinRequestSnapshot.get('displayName') ?? '',
        role: 'child',
        status: 'active',
        createdBy: reviewerId,
        inviteId: joinRequestSnapshot.get('inviteId'),
        createdAt: now,
        updatedAt: now,
      });
      transaction.set(
        userRef,
        {
          familyId,
          role: 'child',
          pendingFamilyId: FieldValue.delete(),
          pendingJoinRequestStatus: FieldValue.delete(),
          updatedAt: now,
        },
        {merge: true},
      );
    } else {
      transaction.set(
        userRef,
        {
          pendingJoinRequestStatus: 'rejected',
          updatedAt: now,
        },
        {merge: true},
      );
    }
  });

  return {status: decision};
});

Object.assign(exports, require('./chat-safety'));

Object.assign(exports, require('./moderation'));
