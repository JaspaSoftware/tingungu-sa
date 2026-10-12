const express = require('express');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { requireAuth } = require('./auth');

const router = express.Router();
const db = () => admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const MIN_AMOUNT = 5;
const MAX_AMOUNT = 50000;

const config = () => ({
  merchantId: process.env.PAYFAST_MERCHANT_ID,
  merchantKey: process.env.PAYFAST_MERCHANT_KEY,
  passphrase: process.env.PAYFAST_PASSPHRASE || '',
  sandbox: process.env.PAYFAST_SANDBOX !== 'false',
  publicApiUrl: (process.env.PUBLIC_API_URL || '').replace(/\/$/, ''),
});

const payfastHost = (sandbox) =>
  sandbox ? 'https://sandbox.payfast.co.za' : 'https://www.payfast.co.za';

// PayFast expects PHP urlencode-style values (spaces as '+').
const encode = (value) =>
  encodeURIComponent(String(value).trim()).replace(/%20/g, '+');

function signature(pairs, passphrase) {
  let str = pairs.map(([k, v]) => `${k}=${encode(v)}`).join('&');
  if (passphrase) str += `&passphrase=${encode(passphrase)}`;
  return crypto.createHash('md5').update(str).digest('hex');
}

function parseAmount(value) {
  const amount = Math.round(Number(value) * 100) / 100;
  if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > MAX_AMOUNT) {
    return null;
  }
  return amount;
}

async function describePurpose(body) {
  const purpose = body.purpose;
  const note = String(body.note || '').slice(0, 200);
  if (purpose === 'topup') {
    return { purpose, label: 'Wallet Top Up', note };
  }
  if (purpose === 'giving') {
    const option = await db().collection('giving_options').doc(String(body.givingOptionId || 'x')).get();
    if (!option.exists) return null;
    return {
      purpose,
      label: `Giving: ${option.data().name || 'Offering'}`,
      givingType: option.data().name || 'Offering',
      note,
    };
  }
  return null;
}

// Records the outcome of a settled payment. Runs inside a Firestore transaction
// so balance, transaction history and giving record can never diverge.
function settle(tx, { uid, displayName, amount, purpose, label, givingType, note, method }) {
  const userRef = db().collection('users').doc(uid);
  const txRef = userRef.collection('transactions').doc();
  tx.set(txRef, {
    amount,
    type: `${label} (${method})`,
    date: FieldValue.serverTimestamp(),
    note: note || '',
  });
  if (purpose === 'giving') {
    tx.set(db().collection('givings').doc(), {
      type: givingType,
      amount,
      giverName: displayName || 'Anonymous',
      giverUID: uid,
      note: note || '',
      createdAt: FieldValue.serverTimestamp(),
      method,
    });
  }
}

// Pay from the wallet balance (giving or airtime).
router.post('/wallet-pay', requireAuth, async (req, res) => {
  try {
    const amount = parseAmount(req.body.amount);
    if (!amount) return res.status(400).json({ error: 'Invalid amount' });
    if (req.body.purpose !== 'giving') {
      return res.status(400).json({ error: 'Invalid purpose' });
    }
    const info = await describePurpose(req.body);
    if (!info) return res.status(400).json({ error: 'Invalid giving option' });

    const uid = req.user.uid;
    await db().runTransaction(async (tx) => {
      const userRef = db().collection('users').doc(uid);
      const snap = await tx.get(userRef);
      if (!snap.exists) throw Object.assign(new Error('User not found'), { status: 404 });
      const balance = Number(snap.data().wallet_balance || 0);
      if (balance < amount) throw Object.assign(new Error('Insufficient wallet balance'), { status: 400 });
      tx.update(userRef, { wallet_balance: Math.round((balance - amount) * 100) / 100 });
      settle(tx, {
        uid,
        displayName: snap.data().displayname || snap.data().display_name || req.user.name,
        amount,
        method: 'Wallet',
        ...info,
      });
    });
    res.json({ success: true });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.status ? err.message : 'Payment failed' });
  }
});

// Start a PayFast payment: the server decides the amount and signs the form.
router.post('/payfast/create', requireAuth, async (req, res) => {
  const cfg = config();
  if (!cfg.merchantId || !cfg.merchantKey || !cfg.publicApiUrl) {
    return res.status(503).json({ error: 'Card payments are not configured' });
  }
  try {
    const amount = parseAmount(req.body.amount);
    if (!amount) return res.status(400).json({ error: 'Invalid amount' });
    const info = await describePurpose(req.body);
    if (!info) return res.status(400).json({ error: 'Invalid payment request' });

    const paymentRef = db().collection('payments').doc();
    await paymentRef.set({
      uid: req.user.uid,
      amount,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      ...info,
    });

    const pairs = [
      ['merchant_id', cfg.merchantId],
      ['merchant_key', cfg.merchantKey],
      ['return_url', 'https://www.tingungu.co.za/success'],
      ['cancel_url', 'https://www.tingungu.co.za/cancel'],
      ['notify_url', `${cfg.publicApiUrl}/api/payments/payfast/notify`],
      ['name_first', (req.user.name || 'Member').split(' ')[0]],
      ['m_payment_id', paymentRef.id],
      ['amount', amount.toFixed(2)],
      ['item_name', info.label.slice(0, 100)],
    ];
    if (req.user.email) pairs.splice(6, 0, ['email_address', req.user.email]);

    const formData = Object.fromEntries(pairs);
    formData.signature = signature(pairs, cfg.passphrase);
    res.json({
      paymentId: paymentRef.id,
      processUrl: `${payfastHost(cfg.sandbox)}/eng/process`,
      formData,
    });
  } catch {
    res.status(500).json({ error: 'Could not start payment' });
  }
});

// Status polling for the app after PayFast redirects back.
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const snap = await db().collection('payments').doc(req.params.id).get();
    if (!snap.exists || snap.data().uid !== req.user.uid) {
      return res.status(404).json({ error: 'Payment not found' });
    }
    res.json({ status: snap.data().status });
  } catch {
    res.status(500).json({ error: 'Could not read payment' });
  }
});

// PayFast server-to-server notification (ITN). This is the only place card
// payments are credited. No auth header: authenticity comes from the signature
// and PayFast's own validation endpoint.
router.post('/payfast/notify', express.text({ type: '*/*', limit: '20kb' }), async (req, res) => {
  const cfg = config();
  try {
    const raw = typeof req.body === 'string' ? req.body : '';
    const pairs = [...new URLSearchParams(raw).entries()];
    const data = Object.fromEntries(pairs);
    const received = data.signature;
    const signed = pairs.filter(([k]) => k !== 'signature');

    if (!received || received !== signature(signed, cfg.passphrase)) return res.status(400).end();
    if (data.merchant_id !== cfg.merchantId) return res.status(400).end();

    const validation = await fetch(`${payfastHost(cfg.sandbox)}/eng/query/validate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: signed.map(([k, v]) => `${k}=${encode(v)}`).join('&'),
    });
    if ((await validation.text()).trim() !== 'VALID') return res.status(400).end();

    const paymentRef = db().collection('payments').doc(String(data.m_payment_id || 'x'));
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(paymentRef);
      if (!snap.exists) throw Object.assign(new Error('unknown'), { status: 400 });
      const payment = snap.data();
      if (payment.status !== 'pending') return;
      if (Math.abs(Number(data.amount_gross) - payment.amount) > 0.001) {
        throw Object.assign(new Error('amount'), { status: 400 });
      }
      if (data.payment_status !== 'COMPLETE') {
        tx.update(paymentRef, { status: 'failed', pfStatus: data.payment_status || '' });
        return;
      }
      const userRef = db().collection('users').doc(payment.uid);
      const user = await tx.get(userRef);
      const userData = user.data() || {};
      if (payment.purpose === 'topup') {
        const balance = Number(userData.wallet_balance || 0);
        tx.set(userRef, { wallet_balance: Math.round((balance + payment.amount) * 100) / 100 }, { merge: true });
      }
      settle(tx, {
        uid: payment.uid,
        displayName: userData.displayname || userData.display_name,
        amount: payment.amount,
        method: 'PayFast',
        purpose: payment.purpose,
        label: payment.label,
        givingType: payment.givingType,
        note: payment.note,
      });
      tx.update(paymentRef, {
        status: 'complete',
        pfPaymentId: data.pf_payment_id || '',
        completedAt: FieldValue.serverTimestamp(),
      });
    });
    res.status(200).end();
  } catch (err) {
    res.status(err.status || 500).end();
  }
});

module.exports = { router, signature, parseAmount };
