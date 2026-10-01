const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const stamp = () => firebase.firestore.FieldValue.serverTimestamp();
(async () => {
 const env = await initializeTestEnvironment({projectId:'gyutto-rules-test',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 let count=0;
 const check=async(name,operation,allowed=false)=>{await (allowed?assertSucceeds:assertFails)(operation);count++;console.log('PASS '+name);};
 try {
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  await db.doc('families/f').set({adminUserId:'admin',name:'Family'});
  for(const [uid,role,status] of [['admin','familyAdmin','active'],['parent','parent','active'],['child','child','active'],['disabled','child','disabled'],['suspended','parent','suspended'],['other','parent','active']]){
   await db.doc(`families/${uid==='other'?'g':'f'}/members/${uid}`).set({userId:uid,role,status,displayName:uid});
  }
  for (const uid of ['admin','parent','child']) {
   await db.doc('families/f/chatAccess/'+uid).set({safetyVersion:1,adultVersion:1,permission:'allowed',permissionVersion:1});
  }
  await db.doc('families/f/messages/m').set({senderUserId:'admin',senderDisplayName:'admin',text:'hello',createdAt:new Date(),readBy:{}});
  await db.doc('families/f/passwordResetRequests/r').set({childUserId:'child',status:'pending'});
  await db.doc('families/f/joinRequests/applicant').set({userId:'applicant',role:'child',status:'pending'});
 });
 const db=uid=>env.authenticatedContext(uid).firestore();
 const child=db('child'),parent=db('parent'),admin=db('admin'),outside=db('other');
 await check('S1 child self promotion',child.doc('families/f/members/child').update({role:'familyAdmin'}));
 await check('S1 child edits parent',child.doc('families/f/members/parent').update({role:'child'}));
 const escalation=child.batch();
 escalation.update(child.doc('families/f/members/child'),{role:'familyAdmin'});
 escalation.delete(child.doc('families/f/members/parent'));
 await check('S1 batch self-promotion cannot authorize deletion',escalation.commit());
 await check('S2 child deletes parent',child.doc('families/f/members/parent').delete());
 await check('S3 child replaces owner',child.doc('families/f').update({adminUserId:'other'}));
 await check('S3 parent replaces owner',parent.doc('families/f').update({adminUserId:'other'}));
 await check('S3 outside self membership',outside.doc('families/f/members/other').set({userId:'other',role:'familyAdmin',status:'active'}));
 await check('S3 recreate membership in existing family',admin.doc('families/f/members/admin').set({userId:'admin',role:'child',status:'active'}));
 const message=(uid)=>({senderUserId:uid,senderDisplayName:uid,text:'hello',createdAt:stamp(),readBy:{[uid]:{displayName:uid,readAt:stamp()}}});
 for(const uid of ['disabled','suspended','other']){
  await check('S4 read '+uid,db(uid).doc('families/f/messages/m').get());
  await check('S4 list '+uid,db(uid).collection('families/f/messages').get());
  await check('S4 post '+uid,db(uid).collection('families/f/messages').add(message(uid)));
  await check('inactive/outside member edit '+uid,db(uid).doc('families/f/members/child').update({role:'parent'}));
 }
 await check('S5 impersonation',child.collection('families/f/messages').add(message('admin')));
 await check('S5 forged display name',child.collection('families/f/messages').add({...message('child'),senderDisplayName:'admin'}));
 await check('normal child post',child.collection('families/f/messages').add(message('child')),true);
 await check('normal parent post',parent.collection('families/f/messages').add(message('parent')),true);
 await check('normal child read',child.doc('families/f/messages/m').get(),true);
 await check('normal receipt',child.doc('families/f/messages/m').set({readBy:{child:{displayName:'child',readAt:stamp()}}},{merge:true}),true);
 await check('S6 remove text',child.doc('families/f/messages/m').update({text:firebase.firestore.FieldValue.delete()}));
 await check('S6 add arbitrary field',child.doc('families/f/messages/m').update({extra:'bad'}));
 await check('S6 change text',child.doc('families/f/messages/m').update({text:'bad'}));
 await check('S6 forge others receipt',child.doc('families/f/messages/m').set({readBy:{parent:{displayName:'parent',readAt:stamp()}}},{merge:true}));
 await check('S7 cross family read',outside.doc('families/f/passwordResetRequests/r').get());
 await check('S7 cross family write',outside.doc('families/f/passwordResetRequests/r').update({status:'approved'}));
 await check('S7 parent read',parent.collection('families/f/passwordResetRequests').where('status','==','pending').get(),true);
 await check('S7 child own read',child.doc('families/f/passwordResetRequests/r').get(),true);
 await check('S7 child self approval',child.doc('families/f/passwordResetRequests/r').update({status:'approved'}));
 const invite=(uid,type='parentInvite')=>({createdBy:uid,type,targetRole:type==='parentInvite'?'parent':'child',status:'active',expiresAt:new Date(Date.now()+3600000)});
 await check('S8 child parent invite',child.doc('families/f/invites/new').set(invite('child')));
 await check('S8 child code index',child.doc('parentInviteCodes/new').set({familyId:'f',type:'parentInvite',status:'active'}));
 await check('S8 child token index',child.doc('childInviteTokens/new').set({familyId:'f',type:'childQrInvite',status:'active'}));
 await check('normal admin parent invite',admin.doc('families/f/invites/new').set(invite('admin')),true);
 await check('normal parent child invite',parent.doc('families/f/invites/kid').set(invite('parent','childQrInvite')),true);
 await check('parent role edit',parent.doc('families/f/members/child').update({role:'parent'}),true);
 await check('admin restore child role',admin.doc('families/f/members/child').update({role:'child'}),true);
 await check('protect owner deletion',parent.doc('families/f/members/admin').delete());
 await check('child cannot delete itself',child.doc('families/f/members/child').delete());
 await check('parent can delete non-owner',parent.doc('families/f/members/disabled').delete(),true);
 await check('parent approval access',parent.collection('families/f/joinRequests').get(),true);
 await check('child approval access',child.collection('families/f/joinRequests').get());
 const newcomer=db('new'); const batch=newcomer.batch();
 batch.set(newcomer.doc('families/new'),{adminUserId:'new',name:'New'});
 batch.set(newcomer.doc('families/new/members/new'),{userId:'new',role:'familyAdmin',status:'active',displayName:'new'});
 await check('normal initial family creation',batch.commit(),true);
 await check('unauthenticated chat',env.unauthenticatedContext().firestore().doc('families/f/messages/m').get());
 console.log(`PASS ${count} security regression checks`);
 } finally {await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
