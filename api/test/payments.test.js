const { test, describe, beforeEach, before, after } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { load, db, startServer, mockFetch, reply } = require('../test-support/harness');

process.env.PAYFAST_MERCHANT_ID = '10000100';
process.env.PAYFAST_MERCHANT_KEY = 'merchant-key';
process.env.PAYFAST_PASSPHRASE = 'secret phrase';
process.env.PAYFAST_SANDBOX = 'true';
process.env.PUBLIC_API_URL = 'https://api.example.com';

const { router, signature, parseAmount } = load('payments');

let server;
before(async () => {
  server = await startServer('/api/payments', router);
});
after(() => server.close());
beforeEach(() => {
  db.reset();
  db.seed('users/u1', { displayname: 'Thabo', wallet_balance: 100 });
  db.seed('giving_options/tithe', { name: 'Tithe' });
});

describe('signature()', () => {
  test('encodes spaces as + and appends the passphrase', () => {
    const pairs = [
      ['merchant_id', '10000100'],
      ['item_name', 'Wallet Top Up'],
    ];
    const expected = crypto
      .createHash('md5')
      .update('merchant_id=10000100&item_name=Wallet+Top+Up&passphrase=secret+phrase')
      .digest('hex');
    assert.equal(signature(pairs, 'secret phrase'), expected);
  });

  test('omits the passphrase when empty', () => {
    const expected = crypto.createHash('md5').update('a=1').digest('hex');
    assert.equal(signature([['a', '1']], ''), expected);
  });
});

describe('parseAmount()', () => {
  test('accepts amounts inside the limits and rounds to cents', () => {
    assert.equal(parseAmount(5), 5);
    assert.equal(parseAmount('10.456'), 10.46);
    assert.equal(parseAmount(50000), 50000);
  });

  test('rejects out-of-range and non-numeric amounts', () => {
    for (const bad of [4.99, 0, -10, 50000.01, 'abc', undefined, null, NaN, Infinity]) {
      assert.equal(parseAmount(bad), null, `expected ${bad} to be rejected`);
    }
  });
});

describe('POST /wallet-pay', () => {
  const giving = { purpose: 'giving', givingOptionId: 'tithe', amount: 40 };

  test('requires authentication', async () => {
    const res = await server.call('POST', '/api/payments/wallet-pay', { body: giving });
    assert.equal(res.status, 401);
  });

  test('rejects invalid amounts, purposes and giving options', async () => {
    const cases = [
      { ...giving, amount: 1 },
      { ...giving, purpose: 'topup' },
      { ...giving, givingOptionId: 'missing' },
    ];
    for (const body of cases) {
      const res = await server.call('POST', '/api/payments/wallet-pay', { uid: 'u1', body });
      assert.equal(res.status, 400, JSON.stringify(body));
    }
    assert.equal(db.read('users/u1').wallet_balance, 100);
  });

  test('rejects a deactivated giving option', async () => {
    db.seed('giving_options/tithe', { name: 'Tithe', active: false });
    const res = await server.call('POST', '/api/payments/wallet-pay', {
      uid: 'u1',
      body: giving,
    });
    assert.equal(res.status, 400);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('givings').length, 0);
  });

  test('enforces persisted giving limits and ignores client-supplied limits', async () => {
    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 50,
      maxAmount: 500,
    });

    for (const amount of [49.99, 500.01]) {
      const res = await server.call('POST', '/api/payments/wallet-pay', {
        uid: 'u1',
        body: { ...giving, amount, minAmount: 0, maxAmount: 0 },
      });
      assert.equal(res.status, 400);
      assert.match(res.json.error, /outside the allowed range/);
    }

    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('users/u1/transactions').length, 0);
    assert.equal(db.list('givings').length, 0);
  });

  test('accepts inclusive giving-option boundaries for wallet payments', async () => {
    db.seed('users/u1', { displayname: 'Thabo', wallet_balance: 1000 });
    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 50,
      maxAmount: 500,
    });

    for (const amount of [50, 500]) {
      const res = await server.call('POST', '/api/payments/wallet-pay', {
        uid: 'u1',
        body: { ...giving, amount },
      });
      assert.equal(res.status, 200);
    }

    assert.equal(db.read('users/u1').wallet_balance, 450);
    assert.equal(db.list('users/u1/transactions').length, 2);
    assert.equal(db.list('givings').length, 2);
  });

  test('treats unset limits as optional and rejects incoherent option limits', async () => {
    const unrestricted = await server.call('POST', '/api/payments/wallet-pay', {
      uid: 'u1',
      body: { ...giving, amount: 5 },
    });
    assert.equal(unrestricted.status, 200);

    db.seed('giving_options/tithe', { name: 'Tithe', minAmount: 50 });
    const minimumOnly = await server.call('POST', '/api/payments/wallet-pay', {
      uid: 'u1',
      body: { ...giving, amount: 50 },
    });
    assert.equal(minimumOnly.status, 200);

    db.seed('giving_options/tithe', { name: 'Tithe', maxAmount: 50 });
    const maximumOnly = await server.call('POST', '/api/payments/wallet-pay', {
      uid: 'u1',
      body: { ...giving, amount: 5 },
    });
    assert.equal(maximumOnly.status, 200);

    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 100,
      maxAmount: 50,
    });
    const invalid = await server.call('POST', '/api/payments/wallet-pay', {
      uid: 'u1',
      body: { ...giving, amount: 40 },
    });
    assert.equal(invalid.status, 500);
    assert.match(invalid.json.error, /payment limits are invalid/);
    assert.equal(db.read('users/u1').wallet_balance, 40);
    assert.equal(db.list('users/u1/transactions').length, 3);
    assert.equal(db.list('givings').length, 3);
  });

  test('refuses to overspend and leaves the balance untouched', async () => {
    const res = await server.call('POST', '/api/payments/wallet-pay', {
      uid: 'u1',
      body: { ...giving, amount: 100.01 },
    });
    assert.equal(res.status, 400);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('givings').length, 0);
  });

  test('debits the wallet and records the transaction and giving together', async () => {
    const res = await server.call('POST', '/api/payments/wallet-pay', { uid: 'u1', body: giving });
    assert.equal(res.status, 200);
    assert.equal(db.read('users/u1').wallet_balance, 60);

    const [transaction] = db.list('users/u1/transactions');
    assert.equal(transaction.amount, 40);
    assert.equal(transaction.type, 'Giving: Tithe (Wallet)');

    const [record] = db.list('givings');
    assert.equal(record.giverUID, 'u1');
    assert.equal(record.amount, 40);
    assert.equal(record.giverName, 'Thabo');
  });

  test('returns 404 for a user without a profile', async () => {
    const res = await server.call('POST', '/api/payments/wallet-pay', { uid: 'ghost', body: giving });
    assert.equal(res.status, 404);
  });
});

describe('POST /payfast/create', () => {
  test('returns 503 when PayFast is not configured', async () => {
    const saved = process.env.PAYFAST_MERCHANT_KEY;
    delete process.env.PAYFAST_MERCHANT_KEY;
    try {
      const res = await server.call('POST', '/api/payments/payfast/create', {
        uid: 'u1',
        body: { purpose: 'topup', amount: 50 },
      });
      assert.equal(res.status, 503);
    } finally {
      process.env.PAYFAST_MERCHANT_KEY = saved;
    }
  });

  test('creates a pending payment and returns a correctly signed form', async () => {
    const res = await server.call('POST', '/api/payments/payfast/create', {
      uid: 'u1',
      body: { purpose: 'topup', amount: 50 },
    });
    assert.equal(res.status, 200);
    assert.equal(res.json.processUrl, 'https://sandbox.payfast.co.za/eng/process');

    const { formData, paymentId } = res.json;
    assert.equal(formData.amount, '50.00');
    assert.equal(formData.m_payment_id, paymentId);
    assert.equal(formData.notify_url, 'https://api.example.com/api/payments/payfast/notify');

    const pairs = Object.entries(formData).filter(([k]) => k !== 'signature');
    assert.equal(formData.signature, signature(pairs, 'secret phrase'));

    const payment = db.read(`payments/${paymentId}`);
    assert.equal(payment.status, 'pending');
    assert.equal(payment.uid, 'u1');
    assert.equal(payment.amount, 50);
  });

  test('rejects invalid amounts and unknown giving options', async () => {
    for (const body of [
      { purpose: 'topup', amount: 2 },
      { purpose: 'giving', givingOptionId: 'missing', amount: 50 },
      { purpose: 'other', amount: 50 },
    ]) {
      const res = await server.call('POST', '/api/payments/payfast/create', { uid: 'u1', body });
      assert.equal(res.status, 400, JSON.stringify(body));
    }
    assert.equal(db.list('payments').length, 0);
  });

  test('enforces persisted giving limits before creating a PayFast payment', async () => {
    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 50,
      maxAmount: 500,
    });

    for (const amount of [49.99, 500.01]) {
      const res = await server.call('POST', '/api/payments/payfast/create', {
        uid: 'u1',
        body: {
          purpose: 'giving',
          givingOptionId: 'tithe',
          amount,
          minAmount: 0,
          maxAmount: 0,
        },
      });
      assert.equal(res.status, 400);
      assert.match(res.json.error, /outside the allowed range/);
    }

    assert.equal(db.list('payments').length, 0);
  });

  test('accepts inclusive giving-option boundaries for PayFast', async () => {
    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 50,
      maxAmount: 500,
    });

    for (const amount of [50, 500]) {
      const res = await server.call('POST', '/api/payments/payfast/create', {
        uid: 'u1',
        body: { purpose: 'giving', givingOptionId: 'tithe', amount },
      });
      assert.equal(res.status, 200);
    }

    assert.deepEqual(
      db.list('payments').map((payment) => payment.amount).sort((a, b) => a - b),
      [50, 500],
    );
  });

  test('preserves general limits when option limits are unset or extend beyond them', async () => {
    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 0,
      maxAmount: 60000,
    });

    const generalMinimum = await server.call('POST', '/api/payments/payfast/create', {
      uid: 'u1',
      body: { purpose: 'giving', givingOptionId: 'tithe', amount: 5 },
    });
    assert.equal(generalMinimum.status, 200);

    const generalMaximum = await server.call('POST', '/api/payments/payfast/create', {
      uid: 'u1',
      body: { purpose: 'giving', givingOptionId: 'tithe', amount: 50000 },
    });
    assert.equal(generalMaximum.status, 200);

    for (const amount of [4.99, 50000.01]) {
      const res = await server.call('POST', '/api/payments/payfast/create', {
        uid: 'u1',
        body: { purpose: 'giving', givingOptionId: 'tithe', amount },
      });
      assert.equal(res.status, 400);
    }

    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 60000,
      maxAmount: 70000,
    });
    const optionMinimumAboveGeneralMaximum = await server.call(
      'POST',
      '/api/payments/payfast/create',
      {
        uid: 'u1',
        body: { purpose: 'giving', givingOptionId: 'tithe', amount: 50000 },
      },
    );
    assert.equal(optionMinimumAboveGeneralMaximum.status, 400);
    assert.equal(db.list('payments').length, 2);
  });

  test('rejects invalid giving-option limits without creating a payment', async () => {
    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 100,
      maxAmount: 50,
    });
    const res = await server.call('POST', '/api/payments/payfast/create', {
      uid: 'u1',
      body: { purpose: 'giving', givingOptionId: 'tithe', amount: 40 },
    });

    assert.equal(res.status, 500);
    assert.match(res.json.error, /payment limits are invalid/);
    assert.equal(db.list('payments').length, 0);

    db.seed('giving_options/tithe', {
      name: 'Tithe',
      minAmount: 'not-an-amount',
      maxAmount: 500,
    });
    const malformed = await server.call('POST', '/api/payments/payfast/create', {
      uid: 'u1',
      body: { purpose: 'giving', givingOptionId: 'tithe', amount: 40 },
    });
    assert.equal(malformed.status, 500);
    assert.match(malformed.json.error, /payment limits are invalid/);
    assert.equal(db.list('payments').length, 0);
  });
});

describe('GET /:id', () => {
  test('only the owner can read a payment status', async () => {
    db.seed('payments/p1', { uid: 'u1', status: 'pending' });
    const own = await server.call('GET', '/api/payments/p1', { uid: 'u1' });
    assert.equal(own.status, 200);
    assert.equal(own.json.status, 'pending');
    const other = await server.call('GET', '/api/payments/p1', { uid: 'u2' });
    assert.equal(other.status, 404);
  });
});

describe('POST /payfast/notify (ITN)', () => {
  let restoreFetch;
  let validation;
  beforeEach(() => {
    validation = 'VALID';
    restoreFetch = mockFetch(async () => reply(200, validation));
  });
  const done = () => restoreFetch();

  function itn(overrides = {}, { sign = true } = {}) {
    const fields = {
      m_payment_id: 'p1',
      pf_payment_id: '1089250',
      payment_status: 'COMPLETE',
      amount_gross: '50.00',
      merchant_id: '10000100',
      ...overrides,
    };
    const pairs = Object.entries(fields);
    const signed = sign ? [...pairs, ['signature', signature(pairs, 'secret phrase')]] : pairs;
    return signed.map(([k, v]) => `${k}=${encodeURIComponent(v).replace(/%20/g, '+')}`).join('&');
  }
  const notify = (raw) =>
    server.call('POST', '/api/payments/payfast/notify', {
      raw,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });
  const seedPayment = (extra = {}) =>
    db.seed('payments/p1', {
      uid: 'u1',
      amount: 50,
      status: 'pending',
      purpose: 'topup',
      label: 'Wallet Top Up',
      ...extra,
    });

  test('rejects a missing or invalid signature', async () => {
    seedPayment();
    assert.equal((await notify(itn({}, { sign: false }))).status, 400);
    assert.equal((await notify(itn().replace(/signature=[0-9a-f]+/, 'signature=deadbeef'))).status, 400);
    assert.equal(
      (await notify(itn({ payment_status: 'CANCELLED' }, { sign: false }))).status,
      400,
    );
    assert.equal(db.read('payments/p1').status, 'pending');
    assert.equal(db.read('users/u1').wallet_balance, 100);
    done();
  });

  test('rejects a different merchant id', async () => {
    seedPayment();
    assert.equal((await notify(itn({ merchant_id: '999' }))).status, 400);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    done();
  });

  test('rejects notifications PayFast does not validate', async () => {
    seedPayment();
    validation = 'INVALID';
    assert.equal((await notify(itn())).status, 400);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    done();
  });

  test('rejects an unknown payment id', async () => {
    assert.equal((await notify(itn({ m_payment_id: 'nope' }))).status, 400);
    done();
  });

  test('rejects an amount that differs from the one we created', async () => {
    seedPayment();
    assert.equal((await notify(itn({ amount_gross: '1.00' }))).status, 400);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.read('payments/p1').status, 'pending');
    done();
  });

  test('credits a completed top-up exactly once, even if PayFast retries', async () => {
    seedPayment();
    assert.equal((await notify(itn())).status, 200);
    assert.equal((await notify(itn())).status, 200);
    assert.equal(db.read('users/u1').wallet_balance, 150);
    assert.equal(db.read('payments/p1').status, 'complete');
    assert.equal(db.list('users/u1/transactions').length, 1);
    done();
  });

  test('marks a verified failed payment failed without crediting', async () => {
    seedPayment();
    assert.equal((await notify(itn({ payment_status: 'FAILED' }))).status, 200);
    assert.equal(db.read('payments/p1').status, 'failed');
    assert.equal(db.read('users/u1').wallet_balance, 100);
    const status = await server.call('GET', '/api/payments/p1', { uid: 'u1' });
    assert.equal(status.status, 200);
    assert.equal(status.json.status, 'failed');
    done();
  });

  test('keeps pending and unknown provider statuses unresolved', async () => {
    seedPayment();
    assert.equal((await notify(itn({ payment_status: 'PENDING' }))).status, 200);
    assert.equal(db.read('payments/p1').status, 'pending');
    assert.equal(db.read('payments/p1').pfStatus, 'PENDING');

    assert.equal((await notify(itn({ payment_status: 'CANCELLED' }))).status, 200);
    assert.equal(db.read('payments/p1').status, 'pending');
    assert.equal(db.read('payments/p1').pfStatus, 'CANCELLED');
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('users/u1/transactions').length, 0);
    const status = await server.call('GET', '/api/payments/p1', { uid: 'u1' });
    assert.equal(status.status, 200);
    assert.equal(status.json.status, 'pending');
    done();
  });

  test('late verified success updates the status after the client has stopped polling', async () => {
    seedPayment();
    const before = await server.call('GET', '/api/payments/p1', { uid: 'u1' });
    assert.equal(before.status, 200);
    assert.equal(before.json.status, 'pending');

    assert.equal((await notify(itn())).status, 200);
    const after = await server.call('GET', '/api/payments/p1', { uid: 'u1' });
    assert.equal(after.status, 200);
    assert.equal(after.json.status, 'complete');
    assert.equal(db.read('users/u1').wallet_balance, 150);
    assert.equal(db.list('users/u1/transactions').length, 1);
    done();
  });

  test('a stale non-final notification cannot overwrite a completed payment', async () => {
    seedPayment();
    assert.equal((await notify(itn())).status, 200);
    assert.equal((await notify(itn({ payment_status: 'PENDING' }))).status, 200);
    assert.equal(db.read('payments/p1').status, 'complete');
    assert.equal(db.read('users/u1').wallet_balance, 150);
    assert.equal(db.list('users/u1/transactions').length, 1);
    done();
  });

  test('a late success cannot overwrite an already-final failed payment', async () => {
    seedPayment();
    assert.equal((await notify(itn({ payment_status: 'FAILED' }))).status, 200);
    assert.equal((await notify(itn())).status, 200);
    assert.equal(db.read('payments/p1').status, 'failed');
    assert.equal(db.read('users/u1').wallet_balance, 100);
    assert.equal(db.list('users/u1/transactions').length, 0);
    done();
  });

  test('records a card giving without touching the wallet', async () => {
    seedPayment({ purpose: 'giving', label: 'Giving: Tithe', givingType: 'Tithe' });
    assert.equal((await notify(itn())).status, 200);
    assert.equal(db.read('users/u1').wallet_balance, 100);
    const [record] = db.list('givings');
    assert.equal(record.giverUID, 'u1');
    assert.equal(record.method, 'PayFast');
    done();
  });
});
