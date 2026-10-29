import assert from 'node:assert/strict';
import test from 'node:test';
import { mapTransactionDocument } from '../src/utils/transactions.js';

function transactionDocument(userId, transactionId, data = {}) {
  const usersCollection = { id: 'users' };
  const userDocument = { id: userId, parent: usersCollection };
  const transactionsCollection = { id: 'transactions', parent: userDocument };

  return {
    id: transactionId,
    ref: { parent: transactionsCollection },
    data: () => data,
  };
}

test('derives each user ID from the transaction document reference', () => {
  const first = mapTransactionDocument(
    transactionDocument('user_123', 'txn_001', { amount: 25 }),
  );
  const second = mapTransactionDocument(
    transactionDocument('user_456', 'txn_002', { amount: 40 }),
  );

  assert.equal(first.userId, 'user_123');
  assert.equal(first.id, 'txn_001');
  assert.equal(first.amount, 25);
  assert.equal(second.userId, 'user_456');
  assert.equal(second.id, 'txn_002');
});

test('owner IDs remain attached through sorting and filtering', () => {
  const transactions = [
    mapTransactionDocument(
      transactionDocument('user_123', 'txn_001', { createdAt: 1, type: 'giving' }),
    ),
    mapTransactionDocument(
      transactionDocument('user_456', 'txn_002', { createdAt: 3, type: 'topup' }),
    ),
    mapTransactionDocument(
      transactionDocument('user_789', 'txn_003', { createdAt: 2, type: 'giving' }),
    ),
  ];

  const sorted = [...transactions].sort((a, b) => b.createdAt - a.createdAt);
  const filtered = sorted.filter(transaction => transaction.type === 'giving');

  assert.deepEqual(
    sorted.map(({ id, userId }) => [id, userId]),
    [
      ['txn_002', 'user_456'],
      ['txn_003', 'user_789'],
      ['txn_001', 'user_123'],
    ],
  );
  assert.deepEqual(
    filtered.map(({ id, userId }) => [id, userId]),
    [
      ['txn_003', 'user_789'],
      ['txn_001', 'user_123'],
    ],
  );
});

test('does not use a transaction field or document ID as its owner ID', () => {
  const transaction = mapTransactionDocument(
    transactionDocument('user_123', 'txn_001', {
      userId: 'legacy_wrong_owner',
      amount: 25,
    }),
  );

  assert.equal(transaction.userId, 'user_123');
  assert.notEqual(transaction.userId, transaction.id);
});

test('returns no owner ID for missing or unexpected references', () => {
  const missingReference = mapTransactionDocument({
    id: 'txn_missing',
    data: () => ({ amount: 10 }),
  });
  const unexpectedParent = mapTransactionDocument({
    id: 'txn_unexpected',
    ref: { parent: { parent: { id: 'user_123', parent: { id: 'archives' } } } },
    data: () => ({ amount: 10 }),
  });

  assert.equal(missingReference.userId, null);
  assert.equal(unexpectedParent.userId, null);
});
