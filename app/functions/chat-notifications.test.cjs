const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function fixture() {
  const docs = {
    'families/f/members/parent': {status: 'active', role: 'parent'},
    'families/f/members/child': {status: 'active', role: 'child'},
    'families/f/chatAccess/parent': {safetyVersion: 1, adultVersion: 1},
    'families/f/chatAccess/child': {safetyVersion: 1, permissionVersion: 1, permission: 'allowed'},
    'families/f/messages/m': {senderUserId: 'parent', senderDisplayName: '親', text: 'こんにちは', readBy: {}},
    'chatPushDevices/d': {uid: 'child', token: 'token-child-1234567890', updatedAt: {toMillis: () => Date.now()}},
    'chatPushDevices/p': {uid: 'parent', token: 'token-parent-1234567890', updatedAt: {toMillis: () => Date.now()}},
  }, sent = [];
  function doc(path) {
    const ref = {
      path, id: path.split('/').at(-1),
      get: async () => snapshot(path),
      set: async data => {docs[path] = data;},
      collection: suffix => collection(`${path}/${suffix}`),
    };
    return ref;
  }
  function snapshot(path) {
    return {id: path.split('/').at(-1), ref: doc(path), exists: !!docs[path],
      data: () => docs[path], get: key => docs[path]?.[key]};
  }
  function collection(path, filter) {
    return {
      doc: id => doc(`${path}/${id}`),
      where: (key, op, value) => collection(path, data => data[key] === value),
      get: async () => ({docs: Object.keys(docs).filter(key =>
        key.startsWith(path + '/') && key.split('/').length === path.split('/').length + 1 &&
        (!filter || filter(docs[key]))).map(snapshot)}),
    };
  }
  const db = {doc, collection, runTransaction: async fn => fn({
    get: ref => ref.get(), set: (ref, data) => {docs[ref.path] = data;},
    delete: ref => {delete docs[ref.path];},
  })};
  const messaging = {send: async payload => {sent.push(payload); return 'sent';}};
  class HttpsError extends Error {constructor(code, message) {super(message); this.code = code;}}
  const scope = {exports: {}, Date, require: name => {
    if (name === 'firebase-functions/v2/https') return {onCall: fn => fn, HttpsError};
    if (name === 'firebase-functions/v2/firestore') return {onDocumentCreated: (options, fn) => fn};
    if (name === 'firebase-admin/firestore') return {getFirestore: () => db, FieldValue: {serverTimestamp: () => ({toMillis: () => Date.now()})}};
    if (name === 'firebase-admin/messaging') return {getMessaging: () => messaging};
    return require(name);
  }};
  vm.runInNewContext(fs.readFileSync(__dirname + '/chat-notifications.js', 'utf8'), scope);
  return {docs, sent, messaging, functions: scope.exports,
    event: {params: {familyId: 'f', messageId: 'm'}},
    request: {auth: {uid: 'child'}, data: {token: 'token-child-1234567890'}}};
}

test('notifies only the unread recipient with channel, sound and tap data', async () => {
  const f = fixture(); await f.functions.notifyFamilyChatMessage(f.event);
  assert.equal(f.sent.length, 1);
  assert.equal(f.sent[0].data.recipientUid, 'child');
  assert.equal(f.sent[0].notification.body, 'こんにちは');
  assert.equal(f.sent[0].android.notification.channelId, 'family_chat');
  assert.equal(f.sent[0].android.notification.sound, 'default');
  await f.functions.notifyFamilyChatMessage(f.event);
  assert.equal(f.sent.length, 1, 'trigger retry must not notify twice');
});
for (const [name, change] of [
  ['already read', f => f.docs['families/f/messages/m'].readBy.child = {}],
  ['paused child', f => f.docs['families/f/chatAccess/child'].permission = 'paused'],
  ['missing consent', f => delete f.docs['families/f/chatAccess/child']],
  ['inactive member', f => f.docs['families/f/members/child'].status = 'disabled'],
  ['deleted account', f => f.docs['accountDeletions/child'] = {}],
  ['stale token', f => f.docs['chatPushDevices/d'].updatedAt = {toMillis: () => 0}],
  ['unknown role', f => f.docs['families/f/members/child'].role = 'stranger'],
]) test(name + ' is not notified', async () => {
  const f = fixture(); change(f); await f.functions.notifyFamilyChatMessage(f.event);
  assert.equal(f.sent.length, 0);
});

test('invalid tokens are removed; transient send failures propagate for retry', async () => {
  const f = fixture();
  f.messaging.send = async () => {throw Object.assign(new Error(), {code: 'messaging/registration-token-not-registered'});};
  await f.functions.notifyFamilyChatMessage(f.event);
  assert.equal(f.docs['chatPushDevices/d'], undefined);
  const g = fixture(); g.messaging.send = async () => {throw new Error('unavailable');};
  await assert.rejects(g.functions.notifyFamilyChatMessage(g.event));
  assert.ok(g.docs['chatPushDevices/d']);
});

test('token is owned by one account and unregister cannot remove another owner', async () => {
  const f = fixture();
  await f.functions.registerChatPushDevice(f.request);
  const hash = require('node:crypto').createHash('sha256').update(f.request.data.token).digest('hex');
  const path = `chatPushDevices/${hash}`;
  assert.equal(f.docs[path].uid, 'child');
  await f.functions.registerChatPushDevice({...f.request, auth: {uid: 'parent'}});
  assert.equal(f.docs[path].uid, 'parent');
  await f.functions.unregisterChatPushDevice(f.request);
  assert.ok(f.docs[path]);
  await f.functions.unregisterChatPushDevice({...f.request, auth: {uid: 'parent'}});
  assert.equal(f.docs[path], undefined);
});

test('unauthenticated, invalid token and deleting users cannot register', async () => {
  const f = fixture();
  await assert.rejects(f.functions.registerChatPushDevice({data: f.request.data}));
  await assert.rejects(f.functions.registerChatPushDevice({...f.request, data: {token: ''}}));
  f.docs['accountDeletions/child'] = {};
  await assert.rejects(f.functions.registerChatPushDevice(f.request));
});
