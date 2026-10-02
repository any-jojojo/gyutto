const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function fixture() {
  const docs = {
    'families/f/members/child': {status:'active',role:'child'},
    'families/f/members/parent': {status:'active',role:'parent'},
    'families/f/messages/m': {text:'actual text',senderUserId:'parent'},
  }, writes = [];
  const db = {
    doc: path => path,
    collection: path => ({doc: () => ({id:'report',path})}),
    runTransaction: fn => fn({
      get: async path => ({exists:!!docs[path],get:key=>docs[path]?.[key]}),
      set: (...args) => writes.push(args),create:(...args)=>writes.push(args),
    }),
  };
  class HttpsError extends Error {constructor(code,message){super(message);this.code=code;}}
  const scope = {exports:{},require:name=> name==='firebase-functions/v2/https'
    ? {onCall:fn=>fn,HttpsError}
    : {getFirestore:()=>db,FieldValue:{serverTimestamp:()=> 'server-time'},Timestamp:{fromMillis:n=>n}}};
  vm.runInNewContext(fs.readFileSync(__dirname+'/moderation.js','utf8'),scope);
  return {docs,writes,functions:scope.exports,request:{auth:{uid:'child'},data:{familyId:'f',kind:'message',targetId:'m',reason:'bullying',details:'help',version:1,accepted:true}}};
}
test('child reports parent with server evidence, ignoring forged identity/text',async()=>{
  const f=fixture();Object.assign(f.request.data,{reporterUserId:'parent',text:'forged'});
  await f.functions.reportChatAbuse(f.request);
  assert.equal(f.writes[0][1].reporterUserId,'child');
  assert.equal(f.writes[0][1].evidence.text,'actual text');
  assert.equal(f.writes[0][1].targetUserId,'parent');
});
test('user report does not require a message or adult approval',async()=>{
  const f=fixture();Object.assign(f.request.data,{kind:'user',targetId:'parent'});
  await f.functions.reportChatAbuse(f.request);assert.equal(f.writes[0][1].evidence,null);
});
for(const [name,change] of [
  ['no auth',f=>f.request.auth=null],
  ['other family',f=>f.request.data.familyId='other'],
  ['disabled reporter',f=>f.docs['families/f/members/child'].status='disabled'],
  ['unknown target',f=>f.request.data.targetId='missing'],
  ['path traversal',f=>f.request.data.targetId='x/y'],
  ['self report',f=>Object.assign(f.request.data,{kind:'user',targetId:'child'})],
  ['invalid reason',f=>f.request.data.reason='bad'],
  ['invalid kind',f=>f.request.data.kind='family'],
  ['oversized details',f=>f.request.data.details='a'.repeat(1001)],
  ['rate limit',f=>f.docs['moderationReportLimits/child']={lastAt:{toMillis:()=>Date.now()}}],
]) test(name+' rejected without writes',async()=>{
  const f=fixture();change(f);await assert.rejects(f.functions.reportChatAbuse(f.request));assert.equal(f.writes.length,0);
});
test('terms stores only current version and server time',async()=>{
  const f=fixture();await f.functions.acceptPostingTerms(f.request);
  assert.deepEqual(Object.keys(f.writes[0][1]).sort(),['postingTermsAcceptedAt','postingTermsVersion']);
});
for(const [name,change] of [
  ['old terms',f=>f.request.data.version=0],
  ['no consent',f=>f.request.data.accepted=false],
  ['outside family',f=>f.request.data.familyId='other'],
  ['disabled member',f=>f.docs['families/f/members/child'].status='disabled'],
]) test(name+' cannot accept terms',async()=>{
  const f=fixture();change(f);await assert.rejects(f.functions.acceptPostingTerms(f.request));assert.equal(f.writes.length,0);
});
