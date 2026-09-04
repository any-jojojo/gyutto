const fs = require('node:fs');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const projectId = 'gyutto-rules-test';

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('families/family-a').set({ adminUserId: 'alice' });
      await db.doc('families/family-b').set({ adminUserId: 'bob' });
      await db.doc('families/family-a/members/alice').set({ userId: 'alice' });
      await db.doc('families/family-b/members/bob').set({
        userId: 'bob', role: 'familyAdmin', status: 'active',
      });
      await db.doc('families/family-b/members/pat').set({
        userId: 'pat', role: 'parent', status: 'active',
      });
      await db.doc('families/family-b/messages/message-1').set({ text: 'secret' });
      await db.doc('families/family-b/invites/valid-invite').set({
        type: 'parentInvite',
        status: 'active',
      });
      await db.doc('families/family-b/invites/used-invite').set({
        type: 'parentInvite',
        status: 'used',
        usedBy: 'someone-else',
      });
      await db.doc('families/family-b/invites/child-invite').set({
        type: 'childQrInvite', status: 'active',
      });
      await db.doc('childInviteTokens/child-token-hash').set({
        familyId: 'family-b', inviteId: 'child-invite',
        type: 'childQrInvite', status: 'active',
      });
    });

    const alice = testEnv.authenticatedContext('alice').firestore();
    const bob = testEnv.authenticatedContext('bob').firestore();
    const mallory = testEnv.authenticatedContext('mallory').firestore();
    const pat = testEnv.authenticatedContext('pat').firestore();
    const child = testEnv.authenticatedContext('child').firestore();

    await assertSucceeds(bob.doc('families/family-b/messages/message-1').get());
    await assertFails(alice.doc('families/family-b/messages/message-1').get());
    await assertFails(
      alice.collection('families/family-b/messages').add({ senderId: 'alice', text: 'attack' }),
    );

    async function attemptJoin(inviteId, usedBy) {
      const member = mallory.doc('families/family-b/members/mallory');
      const invite = mallory.doc(`families/family-b/invites/${inviteId}`);
      const batch = mallory.batch();
      batch.set(member, {
        userId: 'mallory',
        role: 'parent',
        status: 'active',
        createdBy: 'mallory',
        inviteId,
      });
      batch.update(invite, { status: 'used', usedBy });
      return batch.commit();
    }

    await assertFails(attemptJoin('missing-invite', 'mallory'));
    await assertFails(attemptJoin('used-invite', 'mallory'));
    await assertFails(attemptJoin('valid-invite', 'different-user'));

    // A user outside family-b must not be able to forge an invite URL target.
    await assertFails(
      mallory.doc('families/family-b/invites/forged-invite').set({
        type: 'parentInvite',
        status: 'active',
      }),
    );

    const childBatch = child.batch();
    childBatch.set(child.doc('families/family-b/joinRequests/child'), {
      userId: 'child', displayName: 'Child', role: 'child', status: 'pending',
      inviteId: 'child-invite', tokenHash: 'child-token-hash',
    });
    childBatch.update(child.doc('families/family-b/invites/child-invite'), {
      status: 'used', usedBy: 'child', usedAt: new Date(),
    });
    childBatch.update(child.doc('childInviteTokens/child-token-hash'), {
      status: 'used',
    });
    await assertSucceeds(childBatch.commit());
    await assertSucceeds(
      child.doc('families/family-b/joinRequests/child').get(),
    );
    await assertFails(child.collection('families/family-b/joinRequests').get());
    await assertSucceeds(bob.collection('families/family-b/joinRequests').get());
    await assertFails(pat.collection('families/family-b/joinRequests').get());
    await assertFails(
      bob.doc('families/family-b/joinRequests/child').update({status: 'approved'}),
    );

    console.log('PASS same-family chat read');
    console.log('PASS cross-family chat read denied');
    console.log('PASS cross-family chat post denied');
    console.log('PASS missing invite denied');
    console.log('PASS reused invite denied');
    console.log('PASS invite used by another user denied');
    console.log('PASS forged invite denied');
    console.log('PASS valid child invite creates one pending request');
    console.log('PASS child can read only own request');
    console.log('PASS only familyAdmin can list requests');
    console.log('PASS review cannot bypass Cloud Functions');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
