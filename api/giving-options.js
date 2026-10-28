const express = require('express');
const admin = require('firebase-admin');
const { requireAuth, requireAdmin } = require('./auth');

const router = express.Router();
const db = () => admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function validateOption(body) {
  const name = typeof body?.name === 'string' ? body.name.trim() : '';
  if (!name || name.length > 100) {
    const error = new Error('Name is required and must be 100 characters or fewer.');
    error.status = 400;
    throw error;
  }

  const description = body.description == null ? '' : body.description;
  if (typeof description !== 'string' || description.length > 500) {
    const error = new Error('Description must be 500 characters or fewer.');
    error.status = 400;
    throw error;
  }

  const minAmount = body.minAmount == null ? 0 : Number(body.minAmount);
  const maxAmount = body.maxAmount == null ? 0 : Number(body.maxAmount);
  if (
    !Number.isFinite(minAmount) ||
    minAmount < 0 ||
    !Number.isFinite(maxAmount) ||
    maxAmount < 0 ||
    (maxAmount > 0 && minAmount > maxAmount)
  ) {
    const error = new Error('Giving option amounts are invalid.');
    error.status = 400;
    throw error;
  }

  if (body.active != null && typeof body.active !== 'boolean') {
    const error = new Error('Active must be a boolean.');
    error.status = 400;
    throw error;
  }

  return {
    name,
    description: description.trim(),
    minAmount,
    maxAmount,
    active: body.active !== false,
  };
}

function respondWithError(res, error, operation) {
  if (!error.status) {
    console.error(`Giving option ${operation} failed:`, error);
  }
  res.status(error.status || 500).json({
    error: error.status ? error.message : `Could not ${operation} giving option.`,
  });
}

router.use(requireAuth, requireAdmin);

router.post('/', async (req, res) => {
  try {
    const option = validateOption(req.body);
    const ref = await db().collection('giving_options').add({
      ...option,
      createdAt: FieldValue.serverTimestamp(),
    });
    res.status(201).json({ id: ref.id, ...option });
  } catch (error) {
    respondWithError(res, error, 'create');
  }
});

router.put('/:id', async (req, res) => {
  try {
    const option = validateOption(req.body);
    const ref = db().collection('giving_options').doc(req.params.id);
    const existing = await ref.get();
    if (!existing.exists) return res.status(404).json({ error: 'Giving option not found.' });
    await ref.update(option);
    res.json({ id: ref.id, ...option });
  } catch (error) {
    respondWithError(res, error, 'update');
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const ref = db().collection('giving_options').doc(req.params.id);
    const existing = await ref.get();
    if (!existing.exists) return res.status(404).json({ error: 'Giving option not found.' });
    await ref.delete();
    res.status(204).end();
  } catch (error) {
    respondWithError(res, error, 'delete');
  }
});

module.exports = { router, validateOption };
