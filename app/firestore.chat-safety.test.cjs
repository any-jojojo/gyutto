const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

(async () => {
  const env = await initializeTestEnvironment({projectId: 'gyutto-rules-test',
    firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')}});
  let count = 0;
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async c => {
      const db = c.firestore();
      await db.doc('families/f').set({adminUserId:'parent'});
      for (const [uid, role] of [['child','child'],['parent','familyAdmin']]) {
        await db.doc('families/f/members/'+uid).set({userId:uid,displayName:uid,role,status:'active'});
      }
      await db.doc('families/f/messages/m').set({senderUserId:'parent',senderDisplayName:'parent',
        text:'hello',createdAt:new Date(),readBy:{}});
    });
    const child = env.authenticatedContext('child').firestore();
    const parent = env.authenticatedContext('parent').firestore();
    for (const [label, data, allowed] of [
      ['missing consent', null, false],
      ['safety only', {safetyVersion:1}, false],
      ['permission only', {permission:'allowed',permissionVersion:1}, false],
      ['old safety', {safetyVersion:0,permission:'allowed',permissionVersion:1}, false],
      ['old permission', {safetyVersion:1,permission:'allowed',permissionVersion:0}, false],
      ['paused', {safetyVersion:1,permission:'paused',permissionVersion:1}, false],
      ['both confirmed', {safetyVersion:1,permission:'allowed',permissionVersion:1}, true],
    ]) {
      await env.withSecurityRulesDisabled(async c => {
        const ref = c.firestore().doc('families/f/chatAccess/child');
        if (data) await ref.set({...data,postingTermsVersion:1}); else await ref.delete();
      });
      const check = allowed ? assertSucceeds : assertFails;
      await check(child.doc('families/f/messages/m').get());
      await check(child.collection('families/f/messages').get());
      const time = firebase.firestore.FieldValue.serverTimestamp;
      await check(child.doc('families/f/messages/post').set({senderUserId:'child',senderDisplayName:'child',
        text:'hello',createdAt:time(),readBy:{child:{displayName:'child',readAt:time()}}}));
      await check(child.doc('families/f/messages/m').set({readBy:{child:{displayName:'child',readAt:time()}}},{merge:true}));
      console.log('PASS chat gate '+label); count += 4;
    }
    for (const db of [child,parent]) {
      await assertFails(db.doc('families/f/chatAccess/child').set({safetyVersion:1,permission:'allowed',permissionVersion:1}));
      await assertFails(db.doc('families/f/chatAccess/child').delete());
      await assertFails(db.doc('families/f/chatSafetyEvents/forged').set({permission:'allowed'}));
      count += 3;
    }
    await assertFails(parent.doc('families/f/messages/m').get()); count++;
    await env.withSecurityRulesDisabled(c => c.firestore().doc('families/f/chatAccess/parent').set({safetyVersion:1}));
    await assertFails(parent.doc('families/f/messages/m').get()); count++;
    await env.withSecurityRulesDisabled(c => c.firestore().doc('families/f/chatAccess/parent').set({safetyVersion:1,adultVersion:1}));
    await assertSucceeds(parent.doc('families/f/messages/m').get()); count++;
    await env.withSecurityRulesDisabled(c => c.firestore().doc('families/f/members/child').update({status:'disabled'}));
    await assertSucceeds(child.doc('families/f/chatAccess/child').get());
    await assertSucceeds(child.doc('families/f/members/child').get());
    await assertFails(child.doc('families/f/messages/m').get()); count += 3;
    console.log(`PASS ${count} chat safety rule checks`);
  } finally { await env.cleanup(); }
})().catch(e => {console.error(e); process.exitCode = 1;});
