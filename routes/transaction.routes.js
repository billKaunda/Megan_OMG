const { Router } = require('express');
const {
  addTransaction,
  getPendingTransactions,
  getAllTransactions,
} = require('../controllers/transaction.controller');
const { validateBody } = require('../middleware/validateRequest.middleware');
const { writeLimiter } = require('../middleware/rateLimit.middleware');

const router = Router();

router.post('/', writeLimiter, validateBody(['fromAddress', 'toAddress', 'amount']), addTransaction);
router.get('/pending', getPendingTransactions);
router.get('/all', getAllTransactions);

module.exports = router;
