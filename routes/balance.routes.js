const { Router } = require('express');
const { getBalance } = require('../controllers/balance.controller');
const { validateParams } = require('../middleware/validateRequest.middleware');

const router = Router();

router.get('/:address', validateParams(['address']), getBalance);

module.exports = router;
