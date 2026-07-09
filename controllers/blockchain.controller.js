const { blockchain } = require('../models');
const { sendSuccess } = require('../utils/response');

const getChain = (req, res) => {
  sendSuccess(res, {
    chain: blockchain.chain,
    length: blockchain.chain.length,
  });
};

const validateChain = (req, res) => {
  sendSuccess(res, { isValid: blockchain.isChainValid() });
};

module.exports = { getChain, validateChain };
