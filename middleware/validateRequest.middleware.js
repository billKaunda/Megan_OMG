const { sendError } = require('../utils/response');

/**
 * Returns an Express middleware that checks the request body for the
 * presence of every field listed in `requiredFields`.
 *
 * Usage: router.post('/', validateBody(['fromAddress', 'toAddress', 'amount']), handler)
 */
const validateBody = (requiredFields) => (req, res, next) => {
  const missing = requiredFields.filter((field) => {
    const value = req.body[field];
    return value === undefined || value === null || value === '';
  });

  if (missing.length > 0) {
    return sendError(res, `Missing required fields: ${missing.join(', ')}`, 400);
  }

  next();
};

/**
 * Validates route params. Pass an array of param names that must be non-empty.
 */
const validateParams = (requiredParams) => (req, res, next) => {
  const missing = requiredParams.filter((param) => !req.params[param]);

  if (missing.length > 0) {
    return sendError(res, `Missing required params: ${missing.join(', ')}`, 400);
  }

  next();
};

module.exports = { validateBody, validateParams };
