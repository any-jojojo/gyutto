const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
(async () => {
  const env = await initializeTestEnvironment({projectId: 'gyutto-rules-test', firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')}});
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore();
      for (const [uid, role, status] of [['admin', 'familyAdmin', 'active'], ['parent', 'parent', 'active'], ['inactive', 'parent', 'inactive'], ['child', 'child', 'active']]) {
        await db.doc(`families/f/members/${uid}`).set({userId: uid, role, status});
      }
      await db.doc('families/f/joinRequests/applicant').set({userId: 'applicant', role: 'child', status: 'pending'});
    });
    for (const uid of ['admin', 'parent', 'inactive', 'child', 'outsider', 'applicant']) {
      const db = env.authenticatedContext(uid).firestore();
      const allowed = ['admin', 'parent'].includes(uid);
      await (allowed ? assertSucceeds : assertFails)(db.collection('families/f/joinRequests').where('status', '==', 'pending').get());
      await (allowed || uid === 'applicant' ? assertSucceeds : assertFails)(db.doc('families/f/joinRequests/applicant').get());
      await assertFails(db.doc('families/f/joinRequests/applicant').update({status: 'approved'}));
      console.log(`PASS review access ${uid}`);
    }
  } finally { await env.cleanup(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
