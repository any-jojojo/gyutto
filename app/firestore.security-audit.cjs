const fs = require('node:fs');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

async function main() {
  const env = await initializeTestEnvironment({ projectId: 'gyutto-rules-test', firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') } });
  const results = [];
  const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
  async function check(name, allowed, operation) {
    let actual = true, error;
    try { await operation(); } catch (e) {
      if (!['permission-denied', 'PERMISSION_DENIED'].includes(e.code)) throw e;
      actual = false; error = e.code;
    }
    const result = { name, expected: allowed ? 'allowed' : 'denied', actual: actual ? 'allowed' : 'denied', pass: actual === allowed, ...(error ? { error } : {}) };
    results.push(result);
    console.log(`${result.pass ? 'PASS' : 'FAIL'} ${name}: ${result.actual}`);
  }
  async function seedInvite(id, type, expired = false, status = 'active') {
    await env.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      const expiresAt = new Date(Date.now() + (expired ? -3600000 : 3600000));
      const child = type === 'childQrInvite';
      await admin.doc(`families/audit-b/invites/${id}`).set({ type, targetRole: child ? 'child' : 'parent', status, expiresAt, [child ? 'tokenHash' : 'codeHash']: id });
      await admin.doc(`${child ? 'childInviteTokens' : 'parentInviteCodes'}/${id}`).set({ familyId: 'audit-b', inviteId: id, type, targetRole: child ? 'child' : 'parent', status, expiresAt });
    });
  }
  function parentJoin(uid, id, consumeIndex = true) {
    const client = db(uid), batch = client.batch();
    batch.set(client.doc(`families/audit-b/members/${uid}`), { userId: uid, role: 'parent', status: 'active', inviteId: id });
    batch.update(client.doc(`families/audit-b/invites/${id}`), { status: 'used', usedBy: uid });
    if (consumeIndex) batch.update(client.doc(`parentInviteCodes/${id}`), { status: 'used' });
    return batch.commit();
  }
  function childJoin(uid, id, { consume = true, token = id, family = 'audit-b' } = {}) {
    const client = db(uid), batch = client.batch();
    batch.set(client.doc(`families/${family}/joinRequests/${uid}`), { userId: uid, displayName: 'Test child', role: 'child', status: 'pending', inviteId: id, tokenHash: token });
    if (consume) {
      batch.update(client.doc(`families/${family}/invites/${id}`), { status: 'used', usedBy: uid, usedAt: new Date() });
      batch.update(client.doc(`childInviteTokens/${token}`), { status: 'used' });
    }
    return batch.commit();
  }
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      for (const [family, uid] of [['audit-a', 'alice'], ['audit-b', 'bob']]) {
        await admin.doc(`families/${family}`).set({ adminUserId: uid });
        await admin.doc(`families/${family}/members/${uid}`).set({ userId: uid, role: 'familyAdmin', status: 'active' });
        await admin.doc(`families/${family}/messages/one`).set({ text: 'private', senderUserId: uid, readBy: {} });
      }
    });
    await check('same-family read', true, () => db('bob').doc('families/audit-b/messages/one').get());
    await check('same-family post', true, () => db('bob').collection('families/audit-b/messages').add({ text: 'hello', senderUserId: 'bob', readBy: {} }));
    for (const uid of ['alice', null]) {
      const label = uid ? 'cross-family' : 'unauthenticated';
      await check(`${label} read`, false, () => db(uid).doc('families/audit-b/messages/one').get());
      await check(`${label} list`, false, () => db(uid).collection('families/audit-b/messages').get());
      await check(`${label} post`, false, () => db(uid).collection('families/audit-b/messages').add({ text: 'attack', senderUserId: 'bob' }));
      await check(`${label} update`, false, () => db(uid).doc('families/audit-b/messages/one').update({ text: 'attack' }));
      await check(`${label} delete`, false, () => db(uid).doc('families/audit-b/messages/one').delete());
    }
    await check('forged own user profile cannot grant membership', true, () => db('alice').doc('users/alice').set({ familyId: 'audit-b', role: 'familyAdmin' }));
    await check('chat denied after profile forgery', false, () => db('alice').doc('families/audit-b/messages/one').get());
    await check('outsider cannot create invite', false, () => db('mallory').doc('families/audit-b/invites/forged').set({ type: 'parentInvite', status: 'active' }));
    await check('missing invite', false, () => parentJoin('missing-user', 'missing', false));
    await seedInvite('used', 'parentInvite', false, 'used');
    await check('used parent invite', false, () => parentJoin('used-user', 'used'));
    await seedInvite('valid-parent', 'parentInvite');
    await check('valid parent invite', true, () => parentJoin('valid-parent-user', 'valid-parent'));
    await seedInvite('expired-parent', 'parentInvite', true);
    await check('expired parent invite', false, () => parentJoin('expired-parent-user', 'expired-parent'));
    await seedInvite('no-code', 'parentInvite');
    await check('parent join without code index consumption', false, () => parentJoin('no-code-user', 'no-code', false));
    await check('chat after bypassing parent code', false, () => db('no-code-user').doc('families/audit-b/messages/one').get());
    await seedInvite('role-confusion', 'childQrInvite');
    await check('child invite must not grant parent membership', false, () => parentJoin('role-confusion-user', 'role-confusion', false));
    await seedInvite('valid-child', 'childQrInvite');
    await check('valid child pending request', true, () => childJoin('valid-child-user', 'valid-child'));
    await check('pending child cannot read chat', false, () => db('valid-child-user').doc('families/audit-b/messages/one').get());
    await check('pending child cannot post chat', false, () => db('valid-child-user').collection('families/audit-b/messages').add({ text: 'attack' }));
    await check('reused child invite', false, () => childJoin('replay-user', 'valid-child'));
    await seedInvite('expired-child', 'childQrInvite', true);
    await check('expired child invite', false, () => childJoin('expired-child-user', 'expired-child'));
    await seedInvite('tampered-child', 'childQrInvite');
    await check('tampered token', false, () => childJoin('tampered-user', 'tampered-child', { token: 'wrong-token', consume: false }));
    await check('tampered family', false, () => childJoin('family-tamper-user', 'tampered-child', { family: 'audit-a', consume: false }));
    await seedInvite('unconsumed-child', 'childQrInvite');
    await check('child request must consume token atomically', false, () => childJoin('unconsumed-1', 'unconsumed-child', { consume: false }));
    await check('second request with unconsumed token', false, () => childJoin('unconsumed-2', 'unconsumed-child', { consume: false }));
    fs.writeFileSync('security-audit-results.json', JSON.stringify({ testedAt: new Date().toISOString(), scope: 'local Firestore emulator; repository rules only', results }, null, 2));
    console.log(`${results.filter(r => r.pass).length}/${results.length} expectations passed`);
    if (results.some(r => !r.pass)) process.exitCode = 1;
  } finally { await env.cleanup(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
