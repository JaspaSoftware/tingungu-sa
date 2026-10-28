const test = require('node:test');
const assert = require('node:assert/strict');
const { load, db, startServer } = require('../test-support/harness');

test('giving option management', async (t) => {
  db.reset();
  const { router } = load('giving-options');
  const server = await startServer('/api/giving-options', router);
  t.after(() => server.close());

  await t.test('requires an authenticated admin', async () => {
    const anonymous = await server.call('POST', '/api/giving-options', {
      body: { name: 'Tithe' },
    });
    assert.equal(anonymous.status, 401);

    const member = await server.call('POST', '/api/giving-options', {
      uid: 'member-1',
      body: { name: 'Tithe' },
    });
    assert.equal(member.status, 403);
  });

  await t.test('validates options and creates them server-side', async () => {
    const invalid = await server.call('POST', '/api/giving-options', {
      uid: 'admin-1',
      admin: true,
      body: { name: 'Invalid Fund', minAmount: 10, maxAmount: 5 },
    });
    assert.equal(invalid.status, 400);

    const created = await server.call('POST', '/api/giving-options', {
      uid: 'admin-1',
      admin: true,
      body: {
        name: 'Building Fund',
        description: 'Support the building project',
        minAmount: '5',
        maxAmount: '10000',
        active: true,
      },
    });
    assert.equal(created.status, 201);
    assert.equal(created.json.name, 'Building Fund');
    assert.equal(db.list('giving_options').length, 1);
  });

  await t.test('updates and deletes existing options only', async () => {
    db.seed('giving_options/food', {
      name: 'Food Fund',
      description: '',
      minAmount: 0,
      maxAmount: 0,
      active: true,
    });

    const updated = await server.call('PUT', '/api/giving-options/food', {
      uid: 'admin-1',
      admin: true,
      body: { name: 'Food Bank', active: false },
    });
    assert.equal(updated.status, 200);
    assert.equal(db.read('giving_options/food').active, false);

    const missing = await server.call('DELETE', '/api/giving-options/missing', {
      uid: 'admin-1',
      admin: true,
    });
    assert.equal(missing.status, 404);

    const removed = await server.call('DELETE', '/api/giving-options/food', {
      uid: 'admin-1',
      admin: true,
    });
    assert.equal(removed.status, 204);
    assert.equal(db.read('giving_options/food'), undefined);
  });
});
