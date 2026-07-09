const { Router } = require('express');
const { mineBlock } = require('../controllers/mining.controller');
const { writeLimiter } = require('../middleware/rateLimit.middleware');

const router = Router();

router.post('/', writeLimiter, mineBlock);

module.exports = router;
