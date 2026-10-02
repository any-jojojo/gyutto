const fs = require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
(async()=>{
  const env=await initializeTestEnvironment({projectId:'gyutto-rules-test',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async c=>{
      const db=c.firestore();
      await db.doc('families/f/members/child').set({role:'child',status:'active',displayName:'child'});
      await db.doc('families/f/chatAccess/child').set({safetyVersion:1,permission:'allowed',permissionVersion:1});
      await db.doc('moderationReports/r').set({reporterUserId:'child'});
    });
    const db=env.authenticatedContext('child').firestore();
    const time=()=>firebase.firestore.FieldValue.serverTimestamp();
    const post=()=>db.collection('families/f/messages').add({senderUserId:'child',senderDisplayName:'child',text:'hello',createdAt:time(),readBy:{child:{displayName:'child',readAt:time()}}});
    await assertSucceeds(db.collection('families/f/messages').get());
    await assertFails(post());
    await assertFails(db.doc('families/f/chatAccess/child').update({postingTermsVersion:1}));
    for(const version of [0,2,1]) {
      await env.withSecurityRulesDisabled(c=>c.firestore().doc('families/f/chatAccess/child').update({postingTermsVersion:version}));
      await (version===1?assertSucceeds:assertFails)(post());
    }
    for(const uid of ['child','parent','outside']) {
      const client=env.authenticatedContext(uid).firestore();
      for(const path of ['moderationReports/r','moderationReportLimits/child']) {
        await assertFails(client.doc(path).get());
        await assertFails(client.doc(path).set({status:'resolved'}));
        await assertFails(client.doc(path).delete());
      }
      await assertFails(client.collection('moderationReports').get());
    }
    console.log('PASS 27 moderation rule checks');
  } finally {await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
