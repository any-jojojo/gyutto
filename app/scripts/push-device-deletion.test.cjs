const {test} = require('node:test');
const assert = require('node:assert/strict');
const {planDeletion} = require('./account-deletion.cjs');

test('deletion plan removes only the target account push registrations', async () => {
  const documents = [{id: 'a', uid: 'target'}, {id: 'b', uid: 'other'}];
  const db = {listCollections: async () => [{listDocuments: async () => documents.map(data => ({
    path: `chatPushDevices/${data.id}`, parent: {id: 'chatPushDevices'},
    get: async function () {return {exists: true, id: data.id, ref: this, data: () => data};},
    listCollections: async () => [],
  }))}]};
  const plan = await planDeletion(db, 'target');
  assert.deepEqual(plan.deletes, ['chatPushDevices/a']);
  assert.equal(plan.updates.length, 0);
});
