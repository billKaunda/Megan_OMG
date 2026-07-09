const test = require('node:test');
const assert = require('node:assert/strict');

const { Blockchain, Transaction } = require('../models/blockchain');
const persistenceService = require('../services/persistence.service');

const originalStatePath = process.env.BLOCKCHAIN_STATE_PATH;

test.beforeEach(async () => {
  process.env.BLOCKCHAIN_STATE_PATH = `${process.cwd()}/tests/.tmp-blockchain.json`;
  await persistenceService.clear();
});

test.afterEach(async () => {
  if (originalStatePath === undefined) {
    delete process.env.BLOCKCHAIN_STATE_PATH;
  } else {
    process.env.BLOCKCHAIN_STATE_PATH = originalStatePath;
  }
  await persistenceService.clear();
});

test('rejects unsigned transactions', () => {
  const chain = new Blockchain(1, 10);
  const tx = new Transaction('wallet-a', 'wallet-b', 25);

  assert.throws(() => chain.addTransaction(tx), /signature/i);
});

test('persists and restores blockchain state', async () => {
  const chain = new Blockchain(1, 10);
  const tx = new Transaction('wallet-a', 'wallet-b', 25);
  tx.signature = 'signature-placeholder';
  chain.addTransaction(tx);

  await persistenceService.save(chain);
  const restored = await persistenceService.load();

  assert.ok(restored);
  assert.equal(restored.chain.length, 1);
  assert.equal(restored.pendingTransactions.length, 1);
  assert.equal(restored.pendingTransactions[0].amount, 25);
});
