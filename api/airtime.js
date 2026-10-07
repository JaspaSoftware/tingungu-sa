const express = require('express');
const admin = require('firebase-admin');
const { requireAuth } = require('./auth');

const router = express.Router();
const db = () => admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const MIN_AIRTIME = 5;
const MAX_AIRTIME = 1000;
const ALLOWED_PRODUCT_CODES = (process.env.AIRTIME_PRODUCT_CODES || '101,102,103,104')
  .split(',')
  .map((c) => Number(c.trim()))
  .filter(Boolean);

const round2 = (n) => Math.round(n * 100) / 100;
const fail = (status, message) => Object.assign(new Error(message), { status });

const flashConfig = () => ({
  baseUrl: (process.env.FLASH_BASE_URL || '').replace(/\/$/, ''),
  token: process.env.FLASH_TOKEN,
  accountNumber: process.env.FLASH_ACCOUNT_NUMBER,
});

// Returns { outcome: 'success' | 'failed' | 'unknown', ... }.
// 'unknown' (timeouts, 5xx) must not be refunded automatically: the provider
// may still have delivered the airtime.
async function callProvider(cfg, order) {
  try {
    const res = await fetch(`${cfg.baseUrl}/aggregation/4.0/cellular/pinless/purchase`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${cfg.token}`,
      },
      body: JSON.stringify({
        reference: order.id,
        accountNumber: cfg.accountNumber,
        amount: order.amount,
        productCode: order.productCode,
        mobileNumber: order.mobileNumber,
      }),
      signal: AbortSignal.timeout(30000),
    });
    const data = await res.json().catch(() => ({}));
    if (res.ok) return { outcome: 'success', data };
    if (res.status >= 400 && res.status < 500) {
      return { outcome: 'failed', data, status: res.status };
    }
    return { outcome: 'unknown', data, status: res.status };
  } catch (err) {
    return { outcome: 'unknown', error: err.message };
  }
}

// Both helpers only act on orders that are still unsettled, so a retry or an
// overlapping reconciliation run can never pay out or refund twice.
const OPEN_STATES = ['pending', 'review'];

async function completeOrder(orderRef, providerResponse) {
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!OPEN_STATES.includes(snap.data().status)) return;
    const { uid, amount, mobileNumber } = snap.data();
    tx.update(orderRef, {
      status: 'completed',
      providerResponse: providerResponse || {},
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(db().collection('users').doc(uid).collection('transactions').doc(), {
      amount,
      type: `Airtime ${mobileNumber} (Wallet)`,
      date: FieldValue.serverTimestamp(),
      note: '',
    });
  });
}

async function refundOrder(orderRef, providerResponse) {
  await db().runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!OPEN_STATES.includes(orderSnap.data().status)) return;
    const userRef = db().collection('users').doc(orderSnap.data().uid);
    const userSnap = await tx.get(userRef);
    tx.update(userRef, {
      wallet_balance: round2(Number(userSnap.data().wallet_balance || 0) + orderSnap.data().amount),
    });
    tx.update(orderRef, {
      status: 'refunded',
      providerResponse: providerResponse || {},
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}
router.post('/purchase', requireAuth, async (req, res) => {
  const cfg = flashConfig();
  if (!cfg.baseUrl || !cfg.token || !cfg.accountNumber) {
    return res.status(503).json({ error: 'Airtime is not available right now' });
  }

  const amount = Number(req.body.amount);
  const productCode = Number(req.body.productCode);
  const mobileNumber = String(req.body.mobileNumber || '').replace(/[\s-]/g, '');
  if (!Number.isInteger(amount) || amount < MIN_AIRTIME || amount > MAX_AIRTIME) {
    return res.status(400).json({ error: 'Invalid amount' });
  }
  if (!ALLOWED_PRODUCT_CODES.includes(productCode)) {
    return res.status(400).json({ error: 'Invalid network' });
  }
  if (!/^(\+27|0)\d{9}$/.test(mobileNumber)) {
    return res.status(400).json({ error: 'Invalid mobile number' });
  }

  const uid = req.user.uid;
  const orderRef = db().collection('airtime_orders').doc();
  const order = { id: orderRef.id, uid, amount, productCode, mobileNumber };

  try {
    // Reserve the funds and record the order atomically before calling out.
    await db().runTransaction(async (tx) => {
      const userRef = db().collection('users').doc(uid);
      const snap = await tx.get(userRef);
      if (!snap.exists) throw fail(404, 'User not found');
      const balance = Number(snap.data().wallet_balance || 0);
      if (balance < amount) throw fail(400, 'Insufficient wallet balance');
      tx.update(userRef, { wallet_balance: round2(balance - amount) });
      tx.set(orderRef, {
        uid,
        amount,
        productCode,
        mobileNumber,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.status ? err.message : 'Purchase failed' });
  }

  const result = await callProvider(cfg, order);
  const userRef = db().collection('users').doc(uid);

  try {
    if (result.outcome === 'success') {
      await completeOrder(orderRef, result.data);
      return res.json({ success: true });
    }

    if (result.outcome === 'failed') {
      await refundOrder(orderRef, result.data);
      return res.status(502).json({ error: 'The airtime provider declined the purchase. You were not charged.' });
    }
    await orderRef.update({
      status: 'review',
      providerError: result.error || `HTTP ${result.status}`,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return res.status(202).json({
      pending: true,
      error: 'We could not confirm the purchase yet. It will be checked and refunded if it did not go through.',
    });
  } catch (err) {
    console.error('Airtime settlement failed for order', order.id, err);
    return res.status(500).json({ error: 'Purchase could not be completed. Please contact support.' });
  }
});

// --- Reconciliation of orders whose provider outcome was unknown ---

const GRACE_MS = 5 * 60 * 1000;
const GIVE_UP_MS = Number(process.env.AIRTIME_REVIEW_MAX_HOURS || 24) * 3600 * 1000;

// Asks the provider about an order. Only a definite answer settles it:
// 200 = delivered, 404 = the provider never saw the reference. Anything else
// stays in review, because refunding delivered airtime would lose money.
async function lookupOrder(cfg, orderId) {
  const path = (process.env.FLASH_STATUS_PATH || '').replace('{reference}', encodeURIComponent(orderId));
  const res = await fetch(`${cfg.baseUrl}${path}`, {
    headers: { Authorization: `Bearer ${cfg.token}` },
    signal: AbortSignal.timeout(30000),
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 200) return { state: 'delivered', data };
  if (res.status === 404) return { state: 'not_found', data };
  return { state: 'unknown', status: res.status };
}

async function reconcileOrders() {
  const cfg = flashConfig();
  if (!cfg.baseUrl || !cfg.token || !process.env.FLASH_STATUS_PATH) return { skipped: true };

  const snap = await db().collection('airtime_orders').where('status', 'in', OPEN_STATES).get();
  const summary = { delivered: 0, refunded: 0, waiting: 0, escalated: 0 };

  for (const doc of snap.docs) {
    const order = doc.data();
    const age = Date.now() - (order.createdAt?.toMillis?.() || Date.now());
    if (age < GRACE_MS) continue;
    try {
      const found = await lookupOrder(cfg, doc.id);
      if (found.state === 'delivered') {
        await completeOrder(doc.ref, found.data);
        summary.delivered++;
      } else if (found.state === 'not_found') {
        await refundOrder(doc.ref, found.data);
        summary.refunded++;
      } else if (age > GIVE_UP_MS && order.status !== 'manual_review') {
        await doc.ref.update({ status: 'manual_review', updatedAt: FieldValue.serverTimestamp() });
        console.error('Airtime order needs manual review:', doc.id);
        summary.escalated++;
      } else {
        summary.waiting++;
      }
    } catch (err) {
      console.error('Airtime reconcile failed for', doc.id, err.message);
      summary.waiting++;
    }
  }
  return summary;
}

// A Firestore lease keeps scaled-out instances from running the job at once.
async function runWithLease() {
  const ref = db().collection('system').doc('airtime_reconcile');
  const now = Date.now();
  const got = await db().runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (s.exists && s.data().leaseUntil > now) return false;
    tx.set(ref, { leaseUntil: now + 4 * 60 * 1000 });
    return true;
  });
  if (!got) return;
  const summary = await reconcileOrders();
  if (summary && !summary.skipped && Object.values(summary).some(Boolean)) {
    console.log('Airtime reconciliation:', summary);
  }
}

function startReconciler() {
  if (process.env.AIRTIME_RECONCILE === 'off') return;
  const tick = () => runWithLease().catch((e) => console.error('Reconcile error:', e.message));
  setInterval(tick, 5 * 60 * 1000).unref();
}

module.exports = { router, reconcileOrders, startReconciler };
