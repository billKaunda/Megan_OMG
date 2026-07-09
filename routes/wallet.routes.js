const { Router } = require('express');
const { generateWallet, getWalletBalance } = require('../controllers/wallet.controller');
const { validateBody } = require('../middleware/validateRequest.middleware');

const router = Router();

router.post('/', validateBody([]), generateWallet);
router.get('/:address', getWalletBalance);

module.exports = router;
