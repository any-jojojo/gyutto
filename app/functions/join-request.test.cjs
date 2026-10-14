const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {test} = require('node:test');

function fixture(role = 'parent', status = 'active', pending = 'pending', deleting = null) {
  const writes = [];
  const requestData = {role: 'child', status: pending, userId: 'child', displayName: 'Child', inviteId: 'invite'};
  const db = {
    doc: path => path,
    runTransaction: async callback => callback({
      get: async path => ({exists: path.startsWith('accountDeletions/') ? path === 'accountDeletions/'+deleting : role !== 'outsider', get: key =>
        path.endsWith('/members/reviewer') ? ({role, status})[key] : requestData[key]}),
      update: (...args) => writes.push(['update', ...args]),
      create: (...args) => writes.push(['create', ...args]),
      set: (...args) => writes.push(['set', ...args]),
    }),
  };
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const sandbox = {exports: {}, require: name => {
      if (name === './chat-safety' || name === './moderation' || name === './chat-notifications') return {};
    if (name === 'firebase-functions/v2/https') return {onCall: callback => callback, HttpsError};
    if (name === 'firebase-admin/app') return {initializeApp() {}};
    if (name === 'firebase-admin/firestore') return {
      getFirestore: () => db,
      FieldValue: {serverTimestamp: () => 'NOW', delete: () => 'DELETE'},
    };
    throw new Error(name);
  }};
  vm.runInNewContext(fs.readFileSync(__dirname + '/index.js', 'utf8'), sandbox);
  return {review: sandbox.exports.reviewChildJoinRequest, writes};
}
const request = decision => ({auth: {uid: 'reviewer'}, data: {familyId: 'family', userId: 'child', decision}});
for (const uid of ['reviewer','child']) {
  test('deleting '+uid+' cannot approve or regain membership', async()=>{
    const {review,writes}=fixture('parent','active','pending',uid);
    await assert.rejects(review(request('approved')), e=>e.code==='permission-denied');
    assert.equal(writes.length,0);
  });
}
for (const role of ['parent', 'familyAdmin']) {
  test(`${role} can approve and activate child`, async () => {
    const {review, writes} = fixture(role);
    await review(request('approved'));
    assert.equal(writes.find(w => w[0] === 'create')[2].role, 'child');
    assert.equal(writes.find(w => w[0] === 'set')[2].familyId, 'family');
    assert.equal(writes.find(w => w[0] === 'set')[2].pendingFamilyId, 'DELETE');
  });
}
for (const [role, status] of [['child', 'active'], ['parent', 'inactive'], ['outsider', 'active']]) {
  test(`${role}/${status} cannot review`, async () => {
    const {review, writes} = fixture(role, status);
    await assert.rejects(review(request('approved')), {code: 'permission-denied'});
    assert.equal(writes.length, 0);
  });
}
test('reject keeps child out of family', async () => {
  const {review, writes} = fixture();
  await review(request('rejected'));
  assert.equal(writes.filter(w => w[0] === 'create').length, 0);
  assert.equal(writes.find(w => w[0] === 'set')[2].pendingJoinRequestStatus, 'rejected');
});
test('already processed request cannot be approved again', async () => {
  const {review, writes} = fixture('parent', 'active', 'approved');
  await assert.rejects(review(request('approved')), {code: 'failed-precondition'});
  assert.equal(writes.length, 0);
});
test('unauthenticated request rejected', async () => {
  const {review} = fixture();
  await assert.rejects(review({data: request('approved').data}), {code: 'unauthenticated'});
});
