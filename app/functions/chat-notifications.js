const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {createHash} = require('node:crypto');

function device(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const token = request.data?.token;
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096) {
    throw new HttpsError('invalid-argument', '通知の登録情報が正しくありません。');
  }
  return {uid, token, id: createHash('sha256').update(token).digest('hex')};
}

// Tokens are server-only. A shared phone's token belongs to only one account.
exports.registerChatPushDevice = onCall(async request => {
  const {uid, token, id} = device(request), db = getFirestore();
  await db.runTransaction(async tx => {
    const deleted = await tx.get(db.doc(`accountDeletions/${uid}`));
    if (deleted.exists) throw new HttpsError('permission-denied', '削除処理中です。');
    tx.set(db.doc(`chatPushDevices/${id}`), {
      uid, token, updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {registered: true};
});

exports.unregisterChatPushDevice = onCall(async request => {
  const {uid, id} = device(request), db = getFirestore();
  await db.runTransaction(async tx => {
    const ref = db.doc(`chatPushDevices/${id}`), snapshot = await tx.get(ref);
    if (snapshot.get('uid') === uid) tx.delete(ref);
  });
  return {registered: false};
});

function eligible(uid, member, access, message, deleting) {
  if (deleting || member?.status !== 'active' || uid === message.senderUserId ||
      Object.hasOwn(message.readBy ?? {}, uid) || access?.safetyVersion !== 1) return false;
  if (member.role === 'child') {
    return access.permission === 'allowed' && access.permissionVersion === 1;
  }
  return ['parent', 'familyAdmin'].includes(member.role) && access.adultVersion === 1;
}

// Read the current message again so a receipt arriving before delivery suppresses it.
async function deliver({db, messaging, familyId, messageId}) {
  const messageRef = db.doc(`families/${familyId}/messages/${messageId}`);
  const members = await db.collection(`families/${familyId}/members`).get();
  for (const member of members.docs) {
    const uid = member.id;
    const [current, access, deletion, devices] = await Promise.all([
      messageRef.get(), db.doc(`families/${familyId}/chatAccess/${uid}`).get(),
      db.doc(`accountDeletions/${uid}`).get(),
      db.collection('chatPushDevices').where('uid', '==', uid).get(),
    ]);
    const message = current.data();
    if (!message || !eligible(uid, member.data(), access.data(), message, deletion.exists)) continue;
    if (message.createdAt && Date.now() - message.createdAt.toMillis() > 3600000) continue;
    for (const deviceDoc of devices.docs) {
      const deviceData = deviceDoc.data();
      if (!deviceData.token || !deviceData.updatedAt ||
          Date.now() - deviceData.updatedAt.toMillis() > 30 * 86400000) continue;
      const deliveryRef = messageRef.collection('pushDeliveries').doc(deviceDoc.id);
      // Delivery records suppress trigger retries. Android's per-message tag also
      // replaces a duplicate if the process stops between send and acknowledgement.
      const latestDevice = await deviceDoc.ref.get();
      if (latestDevice.get('uid') !== uid || latestDevice.get('token') !== deviceData.token) continue;
      const latest = (await messageRef.get()).data();
      if (!latest || Object.hasOwn(latest.readBy ?? {}, uid)) continue;
      const claimed = await db.runTransaction(async tx => {
        const delivery = await tx.get(deliveryRef);
        if (delivery.get('sentAt')) return false;
        if ((delivery.get('leaseUntil') || 0) > Date.now()) {
          throw new Error('Notification delivery is in progress; retry later.');
        }
        tx.set(deliveryRef, {leaseUntil: Date.now() + 60000});
        return true;
      });
      if (!claimed) continue;
      try {
        await messaging.send({
          token: deviceData.token,
          notification: {
            title: `${String(latest.senderDisplayName || '家族').slice(0, 60)}（ぎゅっと）`,
            body: String(latest.text || '新しいメッセージが届きました').slice(0, 120),
          },
          data: {type: 'family_chat', familyId, messageId, recipientUid: uid},
          android: {priority: 'high', ttl: 3600000, notification: {
            channelId: 'family_chat', icon: 'ic_chat_notification',
            sound: 'default', tag: `${familyId}:${messageId}`,
            visibility: 'private', defaultVibrateTimings: true,
          }},
        });
        await deliveryRef.set({sentAt: FieldValue.serverTimestamp()});
      } catch (error) {
        if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(error.code)) {
          await db.runTransaction(async tx => {
            const fresh = await tx.get(deviceDoc.ref);
            if (fresh.get('uid') === uid && fresh.get('token') === deviceData.token) tx.delete(deviceDoc.ref);
            tx.delete(deliveryRef);
          });
        } else {
          await db.runTransaction(async tx => { tx.delete(deliveryRef); });
          throw error; // Transient FCM failures are retried by the trigger.
        }
      }
    }
  }
}

exports.notifyFamilyChatMessage = onDocumentCreated({
  document: 'families/{familyId}/messages/{messageId}', retry: true,
}, event => deliver({
  db: getFirestore(), messaging: getMessaging(),
  familyId: event.params.familyId, messageId: event.params.messageId,
}));
