/**
 * Persistence service for the assessment blockchain demo.
 *
 * Storage format:
 * {
 *   "chain": [
 *     {
 *       "timestamp": 1710000000000,
 *       "transactions": [],
 *       "previousHash": "0",
 *       "nonce": 0,
 *       "hash": "..."
 *     }
 *   ],
 *   "pendingTransactions": [
 *     {
 *       "fromAddress": "wallet-a",
 *       "toAddress": "wallet-b",
 *       "amount": 25,
 *       "timestamp": 1710000000000,
 *       "signature": ""
 *     }
 *   ],
 *   "difficulty": 2,
 *   "miningReward": 100
 * }
 */

const fs = require('fs/promises');
const path = require('path');
const logger = require('../utils/logger');
const { Blockchain, Transaction } = require('../models/blockchain');

const defaultStatePath = process.env.BLOCKCHAIN_STATE_PATH || path.join(process.cwd(), 'blockchain.json');

const resolveStatePath = () => defaultStatePath;

const restoreBlock = (blockData) => {
  const block = new Blockchain(1, 100);
  const restoredTransactions = (blockData.transactions || []).map((tx) => new Transaction(
    tx.fromAddress,
    tx.toAddress,
    tx.amount,
  ));

  restoredTransactions.forEach((tx, index) => {
    const source = blockData.transactions[index] || {};
    tx.timestamp = source.timestamp || tx.timestamp;
    tx.signature = source.signature || tx.signature;
  });

  block.chain = [];
  block.pendingTransactions = [];
  block.chain.push({
    timestamp: blockData.timestamp,
    transactions: restoredTransactions,
    previousHash: blockData.previousHash,
    nonce: blockData.nonce,
    hash: blockData.hash,
  });

  return block.chain[0];
};

const normalizeState = (state) => {
  if (!state || typeof state !== 'object') {
    return null;
  }

  const chain = Array.isArray(state.chain) ? state.chain : [];
  const pendingTransactions = Array.isArray(state.pendingTransactions) ? state.pendingTransactions : [];
  const difficulty = Number.isFinite(Number(state.difficulty)) ? Number(state.difficulty) : 2;
  const miningReward = Number.isFinite(Number(state.miningReward)) ? Number(state.miningReward) : 100;

  return {
    chain,
    pendingTransactions,
    difficulty,
    miningReward,
  };
};

/**
 * Serialize the current blockchain state and write it to disk.
 *
 * @param {Blockchain} blockchain - The blockchain instance to persist.
 * @returns {Promise<void>}
 */
const save = async (blockchain) => {
  try {
    const payload = {
      chain: blockchain.chain,
      pendingTransactions: blockchain.pendingTransactions,
      difficulty: blockchain.difficulty,
      miningReward: blockchain.miningReward,
    };

    await fs.mkdir(path.dirname(resolveStatePath()), { recursive: true });
    await fs.writeFile(resolveStatePath(), JSON.stringify(payload, null, 2));
    logger.info(`Persisted blockchain state to ${resolveStatePath()}`);
  } catch (error) {
    logger.error(`Failed to persist blockchain state: ${error.message}`);
  }
};

/**
 * Load the persisted blockchain state from disk if it exists.
 *
 * @returns {Promise<Blockchain|null>}
 */
const load = async () => {
  try {
    const raw = await fs.readFile(resolveStatePath(), 'utf8');
    const parsed = JSON.parse(raw);
    const normalized = normalizeState(parsed);

    if (!normalized) {
      logger.warn('Persisted blockchain state was empty; starting fresh.');
      return null;
    }

    const blockchain = new Blockchain(normalized.difficulty, normalized.miningReward);
    blockchain.chain = normalized.chain.map((entry) => {
      const restored = new Block(entry.timestamp, [], entry.previousHash);
      restored.nonce = entry.nonce || 0;
      restored.hash = entry.hash || restored.hash;
      restored.transactions = (entry.transactions || []).map((tx) => {
        const restoredTx = new Transaction(tx.fromAddress, tx.toAddress, tx.amount);
        restoredTx.timestamp = tx.timestamp || restoredTx.timestamp;
        restoredTx.signature = tx.signature || restoredTx.signature;
        return restoredTx;
      });
      return restored;
    });
    blockchain.pendingTransactions = normalized.pendingTransactions.map((tx) => new Transaction(
      tx.fromAddress,
      tx.toAddress,
      tx.amount,
    ));

    blockchain.pendingTransactions.forEach((tx, index) => {
      const source = normalized.pendingTransactions[index] || {};
      tx.timestamp = source.timestamp || tx.timestamp;
      tx.signature = source.signature || tx.signature;
    });

    if (!blockchain.isChainValid()) {
      logger.warn('Persisted blockchain state was invalid; starting fresh.');
      return null;
    }

    logger.info('Restored blockchain state from disk');
    return blockchain;
  } catch (error) {
    if (error.code === 'ENOENT') {
      return null;
    }

    logger.warn(`Unable to load persisted blockchain state: ${error.message}`);
    return null;
  }
};

/**
 * Delete the persisted blockchain state file if it exists.
 *
 * @returns {Promise<void>}
 */
const clear = async () => {
  try {
    await fs.unlink(resolveStatePath());
  } catch (error) {
    if (error.code !== 'ENOENT') {
      logger.warn(`Unable to clear persisted blockchain state: ${error.message}`);
    }
  }
};

module.exports = { save, load, clear };
