const assert = require('node:assert/strict');
const fs = require('node:fs');
const adminRequire = require('node:module').createRequire(require('node:path').resolve(__dirname,'functions/package.json'));
const {initializeApp,deleteApp} = adminRequire('firebase-admin/app');
const {getAuth} = adminRequire('firebase-admin/auth');
const {getFirestore} = adminRequire('firebase-admin/firestore');
const {initializeTestEnvironment,assertFails,assertSucceeds} = require('@firebase/rules-unit-testing');
const {assertEmulators,planDeletion,executeDeletion,allDocuments,finishDeletion} = require('./scripts/account-deletion.cjs');
const projectId='demo-gyutto-deletion';
(async()=>{
  assertEmulators(projectId);
  assert.throws(()=>assertEmulators('gyutto-cb454'));
  const app=initializeApp({projectId});const db=getFirestore(app),auth=getAuth(app);
  const env=await initializeTestEnvironment({projectId,firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  try {
    await env.clearFirestore();
    for(const uid of ['delete-child','keep-parent','delete-owner','pending-child']) {
      await auth.createUser({uid,email:uid+'@example.test',password:'Test-only-12345!'});
    }
    const seed={
      'users/delete-child':{familyId:'f',displayName:'delete me'},
      'users/delete-child/preferences/nested':{setting:'test'},
      'users/keep-parent':{familyId:'f'},
      'families/f':{adminUserId:'keep-parent'},
      'families/f/members/delete-child':{userId:'delete-child',status:'active',role:'child',displayName:'child'},
      'families/f/members/keep-parent':{userId:'keep-parent',status:'active',role:'familyAdmin',displayName:'parent'},
      'families/f/chatAccess/delete-child':{safetyVersion:1,permission:'allowed',permissionVersion:1},
      'families/f/chatAccess/keep-parent':{safetyVersion:1,adultVersion:1,permissionUpdatedBy:'delete-child'},
      'families/f/messages/own':{senderUserId:'delete-child',text:'remove'},
      'families/f/messages/other':{senderUserId:'keep-parent',text:'keep',readBy:{'delete-child':{displayName:'child'},'keep-parent':{displayName:'parent'}}},
      'families/f/chatSafetyEvents/a':{childUserId:'delete-child',changedBy:'keep-parent'},
      'families/f/passwordResetRequests/a':{childUserId:'delete-child'},
      'families/f/invites/i':{createdBy:'keep-parent',usedBy:'delete-child'},
      'childInviteTokens/t':{familyId:'f',inviteId:'i'},
      'parentInviteCodes/c':{familyId:'f',inviteId:'i'},
      'families/old/joinRequests/delete-child':{userId:'delete-child'},
      'families/old/members/other':{userId:'other',createdBy:'delete-child'},
      'families/old/joinRequests/other':{userId:'other',reviewedBy:'delete-child'},
      'families/orphan/messages/m':{senderUserId:'delete-child',text:'orphan parent missing'},
      'moderationReports/report':{reporterUserId:'delete-child',targetUserId:'keep-parent'},
      'moderationReportLimits/delete-child':{lastAt:new Date()},
      'families/owned':{adminUserId:'delete-owner'},
      'users/pending-child':{pendingFamilyId:'unjoined'},
      'families/unjoined/joinRequests/pending-child':{userId:'pending-child',status:'rejected'},
    };
    for(const [path,data] of Object.entries(seed)) await db.doc(path).set(data);
    const before=await planDeletion(db,'delete-child');
    assert.ok(before.deletes.includes('families/orphan/messages/m'));
    assert.ok(before.deletes.includes('users/delete-child/preferences/nested'));
    assert.equal((await db.doc('users/delete-child').get()).exists,true);
    console.log('PASS dry run includes nested and historical data without mutation');
    await assert.rejects(executeDeletion({db,auth,projectId,uid:'delete-owner'}),/transfer/);
    assert.equal((await auth.getUser('delete-owner')).disabled,false);
    console.log('PASS owner deletion blocked without disabling account');
    const oldClient=env.authenticatedContext('delete-child').firestore();
    await assertSucceeds(oldClient.doc('families/f/messages/other').get());
    await executeDeletion({db,auth,projectId,uid:'delete-child'});
    await assert.rejects(auth.getUser('delete-child'),e=>e.code==='auth/user-not-found');
    for(const path of before.deletes) assert.equal((await db.doc(path).get()).exists,false,path);
    const retained=(await db.doc('families/f/messages/other').get()).data();
    assert.equal(retained.text,'keep');assert.deepEqual(Object.keys(retained.readBy),['keep-parent']);
    assert.equal((await db.doc('families/old/members/other').get()).get('createdBy'),undefined);
    assert.equal((await db.doc('families/f/chatAccess/keep-parent').get()).get('adultVersion'),1);
    await auth.getUser('keep-parent');
    console.log('PASS Auth, own documents, receipt, invite indexes, consent and historical references removed; others retained');
    await assertFails(oldClient.doc('families/f/messages/other').get());
    await assertFails(oldClient.doc('users/delete-child').set({displayName:'resurrect'}));
    await assertFails(oldClient.doc('accountDeletions/delete-child').delete());
    await assertFails(oldClient.doc('families/new').set({adminUserId:'delete-child'}));
    await assertSucceeds(env.authenticatedContext('keep-parent').firestore().doc('families/f/messages/other').get());
    const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'delete-child@example.test',password:'Test-only-12345!',returnSecureToken:true})});
    assert.equal(response.ok,false);
    console.log('PASS re-login and stale-token read/profile/family writes denied; retained parent reads');
    await executeDeletion({db,auth,projectId,uid:'delete-child'});
    await executeDeletion({db,auth,projectId,uid:'pending-child'});
    assert.equal((await db.doc('families/unjoined/joinRequests/pending-child').get()).exists,false);
    await db.doc('families/owned').update({adminUserId:'keep-parent'});
    await executeDeletion({db,auth,projectId,uid:'delete-owner'});
    console.log('PASS repeated deletion, pending/rejected account, owner after transfer');
    const documents=await allDocuments(db);
    assert.equal(documents.filter(d=>d.ref.parent.id!=='accountDeletions').some(d=>JSON.stringify(d.data()).includes('delete-child')),false);
    console.log('PASS remaining-data scan (only explicit security tombstones retained)');
    await assert.rejects(finishDeletion({db,auth,projectId,uid:'delete-child'}),/two hours/);
    await db.doc('accountDeletions/delete-child').update({authDeletedAt:new Date(Date.now()-3*60*60*1000)});
    await finishDeletion({db,auth,projectId,uid:'delete-child'});
    assert.equal((await db.doc('accountDeletions/delete-child').get()).exists,false);
    console.log('PASS early finalization refused; security marker removed after simulated waiting period');
  } finally {await env.cleanup();await deleteApp(app);}
})().catch(e=>{console.error(e);process.exitCode=1;});
