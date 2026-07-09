const { Router } = require('express');
const config = require('../config');

const router = Router();

router.get('/', (req, res) => {
  res.status(200).json({
    status: 'ok',
    env: config.env,
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
