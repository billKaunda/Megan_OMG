const { Router } = require('express');
const { getChain, validateChain } = require('../controllers/blockchain.controller');

const router = Router();

router.get('/', getChain);
router.get('/valid', validateChain);

module.exports = router;
