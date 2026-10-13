const { test, describe, beforeEach, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { load, db, startServer, mockFetch, reply, Timestamp } = require('../test-support/harness');

process.env.FLASH_BASE_URL = 'https://flash.example.com';
process.env.FLASH_TOKEN = 'token';
process.env.FLASH_ACCOUNT_NUMBER = '123';
process.env.FLASH_STATUS_PATH = '/status/{reference}';
process.env.AIRTIME_PRODUCT_CODES = '101,102';
process.env.AIRTIME_REVIEW_MAX_HOURS = '24';

const { router, reconcileOrders } = load('airtime');

let server;
let restoreFetch = () => {};
before(async () => {
  server = await startServer('/api/airtime', router);
});
after(() => server.close());
beforeEach(() => {
  restoreFetch();
  db.reset();
  db.seed('users/u1', { displayname: 'Thabo', wallet_balance: 100 });
});

const provider = (handler) => {
  restoreFetch = mockFetch(handler);
};
const purchase = (body, uid = 'u1') =>
  server.call('POST', '/api/airtime/purchase', { uid, body });
const valid = { amount: 20, productCode: 101, mobileNumber: '0821234567' };
const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

describe('POST /purchase validation', () => {
  test('requires authentication', async () => {
    const res = await server.call('POST', '/api/airtime/purchase', { body: valid });
    assert.equal(res.status, 401);
  });

  test('returns 503 when the provider is not configured', async () => {
    const saved = process.env.FLASH_TOKEN;
    delete process.env.FLASH_TOKEN;
    try {
      assert.equal((await purchase(valid)).status, 503);
    } finally {
      process.env.FLASH_TOKEN = saved;
    }
  });

  test('rejects bad amounts, networks and mobile numbers without charging', async () => {
    const cases = [
      { ...valid, amount: 4 },
      { ...valid, amount: 1001 },
      { ...valid, amount: 10.5 },
      { ...valid, productCode: 999 },
      { ...valid, mobileNumber: '12345' },
      { ...valid, mobileNumber: '082123456a' },
    ];
    for (const body of cases) {
      assert.equal((await purchase(body)).status, 400, JSON.stringify(body));
    }
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('airtime_orders').length, 0);
  });

  test('accepts +27 numbers and strips spaces and dashes', async () => {
    let sent;
    provider(async (url, opts) => {
      sent = JSON.parse(opts.body);
      return reply(200, { ok: true });
    });
    const res = await purchase({ ...valid, mobileNumber: '+27 82-123-4567' });
    assert.equal(res.status, 200);
    assert.equal(sent.mobileNumber, '+27821234567');
  });

  test('refuses when the wallet cannot cover the amount and creates no order', async () => {
    let calls = 0;
    provider(async () => {
      calls++;
      return reply(200, {});
    });
    const res = await purchase({ ...valid, amount: 101 });
    assert.equal(res.status, 400);
    assert.equal(calls, 0);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('airtime_orders').length, 0);
  });

  test('returns 404 for a user without a profile', async () => {
    assert.equal((await purchase(valid, 'ghost')).status, 404);
  });
});

describe('POST /purchase provider outcomes', () => {
  test('success: keeps the debit, completes the order and records a transaction', async () => {
    provider(async () => reply(200, { ref: 'x' }));
    const res = await purchase(valid);
    assert.equal(res.status, 200);
    assert.equal(db.read('users/u1').wallet_balance, 80);
    const [order] = db.list('airtime_orders');
    assert.equal(order.status, 'completed');
    assert.equal(order.uid, 'u1');
    const [transaction] = db.list('users/u1/transactions');
    assert.equal(transaction.amount, 20);
    assert.match(transaction.type, /Airtime 0821234567/);
  });

  test('provider rejects (4xx): refunds the wallet and marks the order refunded', async () => {
    provider(async () => reply(400, { error: 'bad' }));
    const res = await purchase(valid);
    assert.equal(res.status, 502);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('airtime_orders')[0].status, 'refunded');
    assert.equal(db.list('users/u1/transactions').length, 0);
  });

  test('provider 5xx: does not refund, parks the order for review', async () => {
    provider(async () => reply(503, {}));
    const res = await purchase(valid);
    assert.equal(res.status, 202);
    assert.equal(db.read('users/u1').wallet_balance, 80);
    assert.equal(db.list('airtime_orders')[0].status, 'review');
  });

  test('network failure/timeout: does not refund, parks the order for review', async () => {
    provider(async () => {
      throw new Error('timeout');
    });
    const res = await purchase(valid);
    assert.equal(res.status, 202);
    assert.equal(db.read('users/u1').wallet_balance, 80);
    assert.equal(db.list('airtime_orders')[0].status, 'review');
  });

  test('sends the order id as the provider reference', async () => {
    let sent;
    provider(async (url, opts) => {
      sent = JSON.parse(opts.body);
      return reply(200, {});
    });
    await purchase(valid);
    assert.equal(sent.reference, db.list('airtime_orders')[0].id);
    assert.equal(sent.amount, 20);
  });
});

describe('reconcileOrders()', () => {
  const seedOrder = (id, { ageMs, status = 'review' } = {}) =>
    db.seed(`airtime_orders/${id}`, {
      uid: 'u1',
      amount: 20,
      mobileNumber: '0821234567',
      productCode: 101,
      status,
      createdAt: new Timestamp(Date.now() - ageMs),
    });

  test('is skipped when no status path is configured', async () => {
    const saved = process.env.FLASH_STATUS_PATH;
    delete process.env.FLASH_STATUS_PATH;
    try {
      assert.deepEqual(await reconcileOrders(), { skipped: true });
    } finally {
      process.env.FLASH_STATUS_PATH = saved;
    }
  });

  test('completes an order the provider says was delivered (200)', async () => {
    seedOrder('o1', { ageMs: 10 * MINUTE });
    provider(async () => reply(200, { delivered: true }));
    const summary = await reconcileOrders();
    assert.equal(summary.delivered, 1);
    assert.equal(db.read('airtime_orders/o1').status, 'completed');
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('users/u1/transactions').length, 1);
  });

  test('refunds an order the provider never saw (404)', async () => {
    seedOrder('o1', { ageMs: 10 * MINUTE });
    provider(async () => reply(404, {}));
    const summary = await reconcileOrders();
    assert.equal(summary.refunded, 1);
    assert.equal(db.read('airtime_orders/o1').status, 'refunded');
    assert.equal(db.read('users/u1').wallet_balance, 120);
  });

  test('never refunds twice when reconciliation runs again', async () => {
    seedOrder('o1', { ageMs: 10 * MINUTE });
    provider(async () => reply(404, {}));
    await reconcileOrders();
    await reconcileOrders();
    assert.equal(db.read('users/u1').wallet_balance, 120);
  });

  test('leaves recent orders alone during the grace period', async () => {
    seedOrder('o1', { ageMs: 1 * MINUTE });
    let calls = 0;
    provider(async () => {
      calls++;
      return reply(404, {});
    });
    await reconcileOrders();
    assert.equal(calls, 0);
    assert.equal(db.read('airtime_orders/o1').status, 'review');
    assert.equal(db.read('users/u1').wallet_balance, 100);
  });

  test('does not refund on an ambiguous provider answer', async () => {
    seedOrder('o1', { ageMs: 10 * MINUTE });
    provider(async () => reply(500, {}));
    const summary = await reconcileOrders();
    assert.equal(summary.waiting, 1);
    assert.equal(db.read('airtime_orders/o1').status, 'review');
    assert.equal(db.read('users/u1').wallet_balance, 100);
  });

  test('escalates long-unresolved orders to manual_review without refunding', async () => {
    seedOrder('o1', { ageMs: 25 * HOUR });
    provider(async () => reply(500, {}));
    const summary = await reconcileOrders();
    assert.equal(summary.escalated, 1);
    assert.equal(db.read('airtime_orders/o1').status, 'manual_review');
    assert.equal(db.read('users/u1').wallet_balance, 100);
  });

  test('ignores orders that are already settled', async () => {
    seedOrder('o1', { ageMs: 10 * MINUTE, status: 'completed' });
    let calls = 0;
    provider(async () => {
      calls++;
      return reply(404, {});
    });
    await reconcileOrders();
    assert.equal(calls, 0);
    assert.equal(db.read('airtime_orders/o1').status, 'completed');
    assert.equal(db.read('users/u1').wallet_balance, 100);
  });
});
