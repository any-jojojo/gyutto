const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {test} = require('node:test');

function fixture({role = 'parent', status = 'active', confirmed = true, targetRole = 'child'} = {}) {
  const writes = [];
  const docs = {
    'families/f/members/actor': {role, status},
    'families/f/chatAccess/actor': confirmed ? {adultVersion: 1} : {},
    'families/f/members/child': {role: targetRole, status: 'active'},
  };
  const db = {
    doc: path => path,
    collection: path => ({doc: () => path + '/event'}),
    runTransaction: async action => action({
      get: async path => ({exists: !!docs[path], get: key => docs[path]?.[key]}),
      set: (...args) => writes.push(args),
      create: (...args) => writes.push(args),
    }),
  };
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const sandbox = {exports: {}, require: name => {
    if (name === 'firebase-functions/v2/https') return {onCall: fn => fn, HttpsError};
    if (name === 'firebase-admin/firestore') return {getFirestore: () => db, FieldValue: {serverTimestamp: () => 'server-time'}};
    throw new Error(name);
  }};
  vm.runInNewContext(fs.readFileSync(__dirname + '/chat-safety.js', 'utf8'), sandbox);
  const request = {
    auth: {uid: 'actor', token: {auth_time: Math.floor(Date.now()/1000), firebase: {sign_in_provider: 'password'}}},
    data: {familyId: 'f', version: 1, adultDeclaration: true, childUserId: 'child', permission: 'allowed'},
  };
  return {functions: sandbox.exports, writes, request};
}
for (const role of ['parent', 'familyAdmin']) {
  test(role + ' can confirm adult status and grant child access', async () => {
    const f = fixture({role});
    await f.functions.confirmAdultForChat(f.request);
    await f.functions.setChildChatPermission(f.request);
    assert.equal(f.writes[0][1].adultVersion, 1);
    assert.equal(f.writes[1][1].permission, 'allowed');
    assert.equal(f.writes[2][1].changedBy, 'actor');
  });
}
for (const [name, change, options] of [
  ['child', () => {}, {role:'child'}],
  ['suspended parent', () => {}, {status:'disabled'}],
  ['missing adult confirmation', () => {}, {confirmed:false}],
  ['outside family', r => r.data.familyId = 'other', {}],
  ['anonymous auth', r => r.auth.token.firebase.sign_in_provider = 'anonymous', {}],
  ['expired reauthentication', r => r.auth.token.auth_time -= 301, {}],
  ['missing auth time', r => delete r.auth.token.auth_time, {}],
  ['non-child target', () => {}, {targetRole:'parent'}],
  ['invalid action', r => r.data.permission = 'anything', {}],
  ['unauthenticated', r => r.auth = null, {}],
]) {
  test(name + ' cannot change child permission', async () => {
    const f = fixture(options); change(f.request);
    await assert.rejects(f.functions.setChildChatPermission(f.request));
    assert.equal(f.writes.length, 0);
  });
}
test('declaration cannot be omitted', async () => {
  const f = fixture(); f.request.data.adultDeclaration = false;
  await assert.rejects(f.functions.confirmAdultForChat(f.request));
  assert.equal(f.writes.length, 0);
});
test('child cannot confirm adulthood even with password authentication', async () => {
  const f = fixture({role:'child'});
  await assert.rejects(f.functions.confirmAdultForChat(f.request));
});
test('safety acknowledgement writes only version and timestamp', async () => {
  const f = fixture({role:'child'});
  f.request.data.permission = 'allowed';
  await f.functions.acknowledgeChatSafety(f.request);
  assert.deepEqual(Object.keys(f.writes[0][1]).sort(), ['safetyAcceptedAt','safetyVersion']);
});
test('old safety version rejected', async () => {
  const f = fixture(); f.request.data.version = 0;
  await assert.rejects(f.functions.acknowledgeChatSafety(f.request));
});
test('disabled child cannot acknowledge', async () => {
  const f = fixture({role:'child',status:'disabled'});
  await assert.rejects(f.functions.acknowledgeChatSafety(f.request));
});
