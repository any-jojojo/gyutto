const assert=require('node:assert/strict');
const {initializeApp,deleteApp}=require('firebase/app');
const {getAuth,connectAuthEmulator,createUserWithEmailAndPassword,signInAnonymously,signOut,signInWithEmailAndPassword}=require('firebase/auth');
const {getFirestore,connectFirestoreEmulator,doc,setDoc,getDoc,getDocs,collection,writeBatch,serverTimestamp,Timestamp,updateDoc}=require('firebase/firestore');
const {getFunctions,connectFunctionsEmulator,httpsCallable}=require('firebase/functions');
const projectId='demo-gyutto-flow';const apps=[];let count=0;
const pass=name=>{count++;console.log('PASS FLOW '+name);};
async function denied(operation){await assert.rejects(operation,e=>String(e.code).includes('permission-denied'));}
async function client(name,anonymous=false){
 const app=initializeApp({projectId,apiKey:'fake-key',authDomain:'localhost'},name);apps.push(app);
 const auth=getAuth(app);connectAuthEmulator(auth,'http://'+process.env.FIREBASE_AUTH_EMULATOR_HOST,{disableWarnings:true});
 const email=name+'@example.test',password='Test-only-12345!';
 const credential=anonymous?await signInAnonymously(auth):await createUserWithEmailAndPassword(auth,email,password);
 const db=getFirestore(app);const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');connectFirestoreEmulator(db,host,Number(port));
 const functions=getFunctions(app);connectFunctionsEmulator(functions,'127.0.0.1',5209);
 return {auth,db,functions,uid:credential.user.uid,name,email,password};
}
const member=(c,role)=>({userId:c.uid,displayName:c.name,role,status:'active',createdBy:c.uid,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
async function invite(c,id,child=false){
 const expiresAt=Timestamp.fromMillis(Date.now()+3600000);const type=child?'childQrInvite':'parentInvite',targetRole=child?'child':'parent';const index=child?'childInviteTokens':'parentInviteCodes';const hash=id+'-hash';const b=writeBatch(c.db);
 b.set(doc(c.db,'families/f/invites/'+id),{type,targetRole,[child?'tokenHash':'codeHash']:hash,createdBy:c.uid,expiresAt,usedAt:null,usedBy:null,status:'active',createdAt:serverTimestamp()});
 b.set(doc(c.db,index+'/'+hash),{familyId:'f',inviteId:id,type,targetRole,expiresAt,status:'active',createdAt:serverTimestamp()});await b.commit();
}
async function childRequest(c,id){const b=writeBatch(c.db);
 b.set(doc(c.db,'families/f/joinRequests/'+c.uid),{userId:c.uid,displayName:c.name,role:'child',status:'pending',inviteId:id,tokenHash:id+'-hash',createdAt:serverTimestamp()});
 b.set(doc(c.db,'users/'+c.uid),{displayName:c.name,pendingFamilyId:'f',pendingJoinRequestStatus:'pending',updatedAt:serverTimestamp()},{merge:true});
 b.update(doc(c.db,'families/f/invites/'+id),{status:'used',usedBy:c.uid,usedAt:serverTimestamp()});b.update(doc(c.db,'childInviteTokens/'+id+'-hash'),{status:'used'});await b.commit();}
(async()=>{
 assert.equal(process.env.GCLOUD_PROJECT,projectId,'Must use isolated demo project');
 const admin=await client('admin'),parent=await client('parent'),child=await client('child',true),other=await client('other'),rejected=await client('rejected',true);pass('email and anonymous registration');
 await signOut(parent.auth);await signInWithEmailAndPassword(parent.auth,parent.email,parent.password);pass('email re-login');
 const b=writeBatch(admin.db);b.set(doc(admin.db,'families/f'),{adminUserId:admin.uid,name:'Test family',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});b.set(doc(admin.db,'families/f/members/'+admin.uid),member(admin,'familyAdmin'));b.set(doc(admin.db,'users/'+admin.uid),{displayName:admin.name,familyId:'f',role:'familyAdmin',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});await b.commit();pass('family registration');
 await invite(admin,'parent');const pb=writeBatch(parent.db);pb.set(doc(parent.db,'families/f/members/'+parent.uid),{...member(parent,'parent'),inviteId:'parent'});pb.set(doc(parent.db,'users/'+parent.uid),{displayName:parent.name,familyId:'f',role:'parent',updatedAt:serverTimestamp()});pb.update(doc(parent.db,'families/f/invites/parent'),{status:'used',usedBy:parent.uid,usedAt:serverTimestamp()});pb.update(doc(parent.db,'parentInviteCodes/parent-hash'),{status:'used'});await pb.commit();pass('parent invitation and join');
 await invite(parent,'child',true);await childRequest(child,'child');pass('parent issues child invite and child requests join');
 await denied(getDocs(collection(child.db,'families/f/messages')));pass('pending child cannot read chat');
 await assert.rejects(httpsCallable(other.functions,'reviewChildJoinRequest')({familyId:'f',userId:child.uid,decision:'approved'}),e=>e.code==='functions/permission-denied');pass('outside approval denied by actual function');
 await httpsCallable(parent.functions,'reviewChildJoinRequest')({familyId:'f',userId:child.uid,decision:'approved'});assert.equal((await getDoc(doc(child.db,'families/f/members/'+child.uid))).data().role,'child');assert.equal((await getDoc(doc(child.db,'users/'+child.uid))).data().familyId,'f');pass('actual parent approval creates membership and user profile');
 await denied(updateDoc(doc(child.db,'families/f/members/'+child.uid),{role:'familyAdmin'}));pass('child cannot promote itself');
 for(const c of [admin,parent,child]){await setDoc(doc(c.db,'families/f/messages/'+c.name),{senderUserId:c.uid,senderDisplayName:c.name,text:'hello '+c.name,createdAt:serverTimestamp(),readBy:{[c.uid]:{displayName:c.name,readAt:serverTimestamp()}}});}assert.equal((await getDocs(collection(child.db,'families/f/messages'))).size,3);pass('admin parent child send and read chat');
 await setDoc(doc(parent.db,'families/f/messages/child'),{readBy:{[parent.uid]:{displayName:parent.name,readAt:serverTimestamp()}}},{merge:true});pass('read receipt update');
 await denied(getDocs(collection(other.db,'families/f/messages')));pass('outside chat denied');
 await updateDoc(doc(parent.db,'families/f/members/'+child.uid),{status:'disabled'});await denied(getDocs(collection(child.db,'families/f/messages')));pass('parent suspension blocks chat');
 await updateDoc(doc(parent.db,'families/f/members/'+child.uid),{status:'active'});await getDocs(collection(child.db,'families/f/messages'));pass('parent reactivation restores chat');
 await invite(admin,'reject',true);await childRequest(rejected,'reject');await httpsCallable(admin.functions,'reviewChildJoinRequest')({familyId:'f',userId:rejected.uid,decision:'rejected'});assert.equal((await getDoc(doc(rejected.db,'families/f/joinRequests/'+rejected.uid))).data().status,'rejected');await denied(getDocs(collection(rejected.db,'families/f/messages')));pass('actual admin rejection keeps chat blocked');
 console.log(`PASS ${count} full flow checks`);
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>{await Promise.all(apps.map(deleteApp));});
