const fs = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

async function main() {
  const env = await initializeTestEnvironment({ projectId: 'gyutto-rules-test', firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') } });
  let count = 0;
  async function scenario(name, { invite = {}, code = {}, parts = ['member', 'invite', 'code', 'user'], invitePatch = {}, codePatch = {}, memberPatch = {}, uid = 'new-parent', allowed = false } = {}) {
    await env.clearFirestore();
    const expiresAt = new Date(Date.now() + 3600000);
    await env.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      await admin.doc('families/b').set({ adminUserId: 'admin' });
      await admin.doc('families/b/members/admin').set({ userId: 'admin', role: 'familyAdmin', status: 'active' });
      await admin.doc('families/b/invites/i').set({ type: 'parentInvite', targetRole: 'parent', codeHash: 'hash', status: 'active', expiresAt, ...invite });
      await admin.doc('parentInviteCodes/hash').set({ familyId: 'b', inviteId: 'i', type: 'parentInvite', targetRole: 'parent', status: 'active', expiresAt, ...code });
    });
    const client = env.authenticatedContext(uid).firestore();
    const batch = client.batch();
    if (parts.includes('member')) batch.set(client.doc(`families/b/members/${uid}`), { userId: uid, role: 'parent', status: 'active', inviteId: 'i', ...memberPatch });
    if (parts.includes('invite')) batch.update(client.doc('families/b/invites/i'), { status: 'used', usedBy: uid, usedAt: new Date(), ...invitePatch });
    if (parts.includes('code')) batch.update(client.doc('parentInviteCodes/hash'), { status: 'used', ...codePatch });
    if (parts.includes('user')) batch.set(client.doc(`users/${uid}`), { familyId: 'b', role: 'parent' });
    await (allowed ? assertSucceeds(batch.commit()) : assertFails(batch.commit()));
    if (allowed) {
      const replayClient = env.authenticatedContext('replay-parent').firestore();
      const replay = replayClient.batch();
      replay.set(replayClient.doc('families/b/members/replay-parent'), { userId: 'replay-parent', role: 'parent', status: 'active', inviteId: 'i' });
      replay.update(replayClient.doc('families/b/invites/i'), { status: 'used', usedBy: 'replay-parent' });
      replay.update(replayClient.doc('parentInviteCodes/hash'), { status: 'used' });
      await assertFails(replay.commit());
    }
    await env.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      const member = await admin.doc(`families/b/members/${uid}`).get();
      if (uid !== 'admin' && member.exists !== allowed) throw new Error('Unexpected membership after batch');
      const saved = await admin.doc('parentInviteCodes/hash').get();
      if (saved.get('status') !== (allowed ? 'used' : (code.status ?? 'active'))) throw new Error('Partial code consumption');
      const savedInvite = await admin.doc('families/b/invites/i').get();
      if (savedInvite.get('status') !== (allowed ? 'used' : (invite.status ?? 'active'))) throw new Error('Partial invite consumption');
    });
    console.log(`PASS ${name}`); count++;
  }
  try {
    await scenario('valid app-shaped four-document batch', { allowed: true });
    await scenario('expired invite', { invite: { expiresAt: new Date(0) } });
    await scenario('expired code', { code: { expiresAt: new Date(0) } });
    await scenario('missing expiry', { invite: { expiresAt: null } });
    await scenario('wrong invite type', { invite: { type: 'childQrInvite' } });
    await scenario('wrong invite role', { invite: { targetRole: 'child' } });
    await scenario('wrong code type', { code: { type: 'childQrInvite' } });
    await scenario('wrong code role', { code: { targetRole: 'child' } });
    await scenario('wrong code family', { code: { familyId: 'other' } });
    await scenario('wrong code invite', { code: { inviteId: 'other' } });
    await scenario('missing code index', { invite: { codeHash: 'missing' } });
    await scenario('used code', { code: { status: 'used' } });
    await scenario('used invite', { invite: { status: 'used' } });
    for (const parts of [['member'], ['invite'], ['code'], ['member', 'invite'], ['member', 'code'], ['invite', 'code']]) {
      await scenario(`incomplete batch ${parts.join('+')}`, { parts });
    }
    await scenario('wrong usedBy', { invitePatch: { usedBy: 'other' } });
    await scenario('role escalation', { memberPatch: { role: 'familyAdmin' } });
    await scenario('invite expiry tampering', { invitePatch: { expiresAt: new Date(Date.now() + 7200000) } });
    await scenario('invite added field', { invitePatch: { injected: true } });
    await scenario('code added field', { codePatch: { injected: true } });
    await scenario('code family tampering', { codePatch: { familyId: 'other' } });
    await scenario('existing administrator cannot consume invite alone', { uid: 'admin', parts: ['invite'] });
    console.log(`PASS ${count} parent invite scenarios`);
  } finally { await env.cleanup(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
