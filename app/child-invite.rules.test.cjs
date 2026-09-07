const fs = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

async function main() {
  const env = await initializeTestEnvironment({ projectId: 'gyutto-rules-test', firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') } });
  let count = 0;
  async function scenario(name, { invite = {}, token = {}, parts = ['request', 'invite', 'token', 'user'], invitePatch = {}, tokenPatch = {}, joinPatch = {}, uid = 'child', allowed = false } = {}) {
    await env.clearFirestore();
    const expiresAt = new Date(Date.now() + 3600000);
    await env.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      await admin.doc('families/b').set({ adminUserId: 'admin' });
      await admin.doc('families/b/members/admin').set({ userId: 'admin', role: 'familyAdmin' });
      await admin.doc('families/b/invites/i').set({ type: 'childQrInvite', targetRole: 'child', tokenHash: 'hash', status: 'active', expiresAt, ...invite });
      await admin.doc('childInviteTokens/hash').set({ familyId: 'b', inviteId: 'i', type: 'childQrInvite', targetRole: 'child', status: 'active', expiresAt, ...token });
    });
    function join(userId, selectedParts = parts) {
      const client = env.authenticatedContext(userId).firestore(), batch = client.batch();
      if (selectedParts.includes('request')) batch.set(client.doc(`families/b/joinRequests/${userId}`), { userId, displayName: 'Child', role: 'child', status: 'pending', inviteId: 'i', tokenHash: 'hash', ...joinPatch });
      if (selectedParts.includes('invite')) batch.update(client.doc('families/b/invites/i'), { status: 'used', usedBy: userId, usedAt: new Date(), ...invitePatch });
      if (selectedParts.includes('token')) batch.update(client.doc('childInviteTokens/hash'), { status: 'used', ...tokenPatch });
      if (selectedParts.includes('user')) batch.set(client.doc(`users/${userId}`), { pendingFamilyId: 'b', pendingJoinRequestStatus: 'pending' });
      return batch.commit();
    }
    await (allowed ? assertSucceeds(join(uid)) : assertFails(join(uid)));
    if (allowed) await assertFails(join('replay-child'));
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore();
      if ((await db.doc(`families/b/joinRequests/${uid}`).get()).exists !== allowed) throw new Error('Unexpected request');
      if ((await db.doc('families/b/invites/i').get()).get('status') !== (allowed ? 'used' : (invite.status ?? 'active'))) throw new Error('Partial invite consumption');
      if ((await db.doc('childInviteTokens/hash').get()).get('status') !== (allowed ? 'used' : (token.status ?? 'active'))) throw new Error('Partial token consumption');
    });
    console.log(`PASS ${name}`); count++;
  }
  try {
    await scenario('valid app-shaped batch and replay denied', { allowed: true });
    await scenario('expired invite', { invite: { expiresAt: new Date(0) } });
    await scenario('expired token', { token: { expiresAt: new Date(0) } });
    await scenario('missing invite expiry', { invite: { expiresAt: null } });
    await scenario('invalid token expiry', { token: { expiresAt: '2099' } });
    await scenario('wrong invite type', { invite: { type: 'parentInvite' } });
    await scenario('wrong token type', { token: { type: 'parentInvite' } });
    await scenario('wrong target role', { token: { targetRole: 'parent' } });
    await scenario('wrong token family', { token: { familyId: 'other' } });
    await scenario('wrong token invite', { token: { inviteId: 'other' } });
    await scenario('wrong invite token hash', { invite: { tokenHash: 'other' } });
    await scenario('used invite', { invite: { status: 'used' } });
    await scenario('used token', { token: { status: 'used' } });
    for (const parts of [['request'], ['invite'], ['token'], ['request', 'invite'], ['request', 'token'], ['invite', 'token']]) await scenario(`incomplete batch ${parts.join('+')}`, { parts });
    await scenario('wrong usedBy', { invitePatch: { usedBy: 'other' } });
    await scenario('wrong request user', { joinPatch: { userId: 'other' } });
    await scenario('parent request role', { joinPatch: { role: 'parent' } });
    await scenario('self-approved request', { joinPatch: { status: 'approved' } });
    await scenario('added invite field', { invitePatch: { injected: true } });
    await scenario('added token field', { tokenPatch: { injected: true } });
    await scenario('token family tampering', { tokenPatch: { familyId: 'other' } });
    await scenario('admin cannot consume invite alone', { uid: 'admin', parts: ['invite'] });
    console.log(`PASS ${count} child invite scenarios`);
  } finally { await env.cleanup(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
