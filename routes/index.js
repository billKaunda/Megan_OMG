const { Router } = require('express');
const blockchainRoutes = require('./blockchain.routes');
const transactionRoutes = require('./transaction.routes');
const miningRoutes = require('./mining.routes');
const balanceRoutes = require('./balance.routes');
const statsRoutes = require('./stats.routes');
const walletRoutes = require('./wallet.routes');

const router = Router();

router.use('/chain', blockchainRoutes);
router.use('/transactions', transactionRoutes);
router.use('/mine', miningRoutes);
router.use('/balance', balanceRoutes);
router.use('/stats', statsRoutes);
router.use('/wallets', walletRoutes);

module.exports = router;
