const test = require('node:test');
const assert = require('node:assert/strict');
const { load, db, startServer } = require('../test-support/harness');

test('POST /api/contact', async (t) => {
  db.reset();
  const { router } = load('contact');
  const server = await startServer('/api/contact', router);
  t.after(() => server.close());

  await t.test('rejects missing required fields', async () => {
    const response = await server.call('POST', '/api/contact', {
      body: { name: 'Jane', email: 'jane@example.com' },
    });

    assert.equal(response.status, 400);
    assert.match(response.json.error, /required/);
  });

  await t.test('rejects invalid email addresses', async () => {
    const response = await server.call('POST', '/api/contact', {
      body: { name: 'Jane', email: 'not-an-email', message: 'Please call me.' },
    });

    assert.equal(response.status, 400);
    assert.match(response.json.error, /valid email/);
  });

  await t.test('stores valid submissions for admins and confirms receipt', async () => {
    const response = await server.call('POST', '/api/contact', {
      body: {
        name: ' Jane Doe ',
        email: ' jane@example.com ',
        website: ' https://example.com ',
        message: ' Please contact me. ',
      },
    });

    assert.equal(response.status, 201);
    assert.equal(response.json.success, true);

    const [ticket] = db.list('support_tickets');
    assert.equal(ticket.contactName, 'Jane Doe');
    assert.equal(ticket.userEmail, 'jane@example.com');
    assert.equal(ticket.website, 'https://example.com');
    assert.equal(ticket.message, 'Please contact me.');
    assert.equal(ticket.source, 'website');
    assert.equal(ticket.status, 'open');
  });
});
