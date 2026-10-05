// Operational rehearsal only. Deliberately refuses all production endpoints.
const {FieldValue, FieldPath} = require('node:module').createRequire(require('node:path').resolve(__dirname,'../functions/package.json'))('firebase-admin/firestore');
function assertEmulators(projectId) {
  if (!projectId?.startsWith('demo-') ||
      !/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '') ||
      !/^127\.0\.0\.1:\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST || '')) {
    throw new Error('Deletion rehearsal requires demo project and localhost Auth/Firestore emulators');
  }
}
async function allDocuments(db) {
  const result = [];
  async function walk(collection) {
    for (const ref of await collection.listDocuments()) {
      const snapshot = await ref.get();
      if (snapshot.exists) result.push(snapshot);
      for (const sub of await ref.listCollections()) await walk(sub);
    }
  }
  for (const collection of await db.listCollections()) await walk(collection);
  return result;
}
const referenceFields = new Set(['createdBy','usedBy','reviewedBy','approvedBy','requestedBy',
  'permissionUpdatedBy','changedBy','userId','childUserId','senderUserId','reporterUserId','targetUserId']);
async function planDeletion(db, uid) {
  if (typeof uid !== 'string' || !uid || uid.includes('/')) throw new Error('Invalid UID');
  const documents = await allDocuments(db), deletes = new Set(), updates = [], blockers = [];
  for (const d of documents) {
    const p = d.ref.path.split('/'), data = d.data(), collection = p.at(-2);
    if (p[0] === 'families' && p.length === 2 && data.adminUserId === uid) {
      blockers.push(d.ref.path + ': transfer family ownership before member deletion');
    }
    if ((p[0] === 'users' && p[1] === uid) ||
        (['members','chatAccess','joinRequests'].includes(collection) && d.id === uid) ||
        (collection === 'messages' && data.senderUserId === uid) ||
        (collection === 'passwordResetRequests' && data.childUserId === uid) ||
        (collection === 'chatSafetyEvents' && (data.childUserId === uid || data.changedBy === uid)) ||
        (collection === 'invites' && (data.createdBy === uid || data.usedBy === uid)) ||
        (collection === 'moderationReports' && (data.reporterUserId === uid || data.targetUserId === uid)) ||
        (collection === 'moderationReportLimits' && d.id === uid)) deletes.add(d.ref.path);
  }
  // Removing a document never removes its subcollections automatically.
  for (const d of documents) {
    if ([...deletes].some(path => d.ref.path.startsWith(path + '/'))) deletes.add(d.ref.path);
    const data = d.data();
    if (['parentInviteCodes','childInviteTokens'].includes(d.ref.parent.id) &&
        deletes.has(`families/${data.familyId}/invites/${data.inviteId}`)) deletes.add(d.ref.path);
  }
  for (const d of documents) {
    if (deletes.has(d.ref.path)) continue;
    const fields = [];
    for (const [key,value] of Object.entries(d.data())) {
      if (referenceFields.has(key) && value === uid) fields.push([key]);
    }
    if (Object.hasOwn(d.data().readBy || {}, uid)) fields.push(['readBy',uid]);
    if (fields.length) updates.push({path:d.ref.path,fields});
  }
  return {uid,deletes:[...deletes].sort(),updates,blockers};
}
async function executeDeletion({db,auth,projectId,uid}) {
  assertEmulators(projectId);
  let plan = await planDeletion(db,uid);
  if (plan.blockers.length) throw new Error(plan.blockers.join('\n'));
  await db.doc(`accountDeletions/${uid}`).set({startedAt:FieldValue.serverTimestamp()});
  // Remove memberships first: old ID tokens must lose chat access immediately.
  for (const path of plan.deletes.filter(p => p.split('/').at(-2) === 'members')) await db.doc(path).delete();
  try {
    await auth.updateUser(uid,{disabled:true});
    await auth.revokeRefreshTokens(uid);
  } catch (e) { if(e.code !== 'auth/user-not-found') throw e; }
  // Re-read after cutting off client membership writes; repeatable after partial failure.
  plan = await planDeletion(db,uid);
  if (plan.blockers.length) throw new Error(plan.blockers.join('\n'));
  for (const update of plan.updates) {
    await db.doc(update.path).update(...update.fields.flatMap(parts => [new FieldPath(...parts),FieldValue.delete()]));
  }
  for (const path of plan.deletes.sort((a,b)=>b.split('/').length-a.split('/').length)) await db.doc(path).delete();
  try { await auth.deleteUser(uid); } catch(e) { if(e.code !== 'auth/user-not-found') throw e; }
  await db.doc(`accountDeletions/${uid}`).set({authDeletedAt:FieldValue.serverTimestamp()}, {merge:true});
  const remaining = await planDeletion(db,uid);
  if (remaining.deletes.length || remaining.updates.length || remaining.blockers.length) throw new Error('Deletion verification failed');
  return {uid,verified:true};
}
async function finishDeletion({db,auth,projectId,uid}) {
  assertEmulators(projectId);
  if (typeof uid !== 'string' || !uid || uid.includes('/')) throw new Error('Invalid UID');
  const ref=db.doc(`accountDeletions/${uid}`), marker=await ref.get();
  const deletedAt=marker.get('authDeletedAt');
  if (!deletedAt || Date.now()-deletedAt.toMillis()<2*60*60*1000) throw new Error('Wait at least two hours after Auth deletion');
  try {await auth.getUser(uid);throw new Error('Auth user still exists');} catch(e) {if(e.code!=='auth/user-not-found')throw e;}
  const remaining=await planDeletion(db,uid);
  if(remaining.deletes.length || remaining.updates.length || remaining.blockers.length)throw new Error('Residual data requires review');
  await ref.delete();
  return {uid,completed:true};
}
module.exports = {assertEmulators,allDocuments,planDeletion,executeDeletion,finishDeletion};
