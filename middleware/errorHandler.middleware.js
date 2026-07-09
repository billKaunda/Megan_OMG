const logger = require('../utils/logger');
const { sendError } = require('../utils/response');

// Express requires the 4-argument signature to recognise an error handler
// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  const status = err.status || err.statusCode || 500;
  const message =
    status < 500 ? err.message : 'An unexpected error occurred';

  logger.error(`[${req.method}] ${req.originalUrl} → ${status}: ${err.message}`);

  sendError(res, message, status);
};

module.exports = errorHandler;
