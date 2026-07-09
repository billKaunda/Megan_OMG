const { blockchain } = require('../models');
const { sendSuccess, sendError } = require('../utils/response');
const { isValidAddress, sanitizeAddress } = require('../utils/validator');

const getBalance = (req, res) => {
  const address = sanitizeAddress(req.params.address);

  if (!isValidAddress(address)) {
    return sendError(res, 'Invalid wallet address', 400);
  }

  const balance = blockchain.getBalanceOfAddress(address);

  sendSuccess(res, { address, balance });
};

module.exports = { getBalance };
