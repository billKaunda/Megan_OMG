/**
 * Unified JSON response helpers.
 * All API responses follow the same shape:
 *   success responses  → { success: true,  ...payload }
 *   error responses    → { success: false, error: string }
 */

const sendSuccess = (res, payload = {}, statusCode = 200) => {
  res.status(statusCode).json({ success: true, ...payload });
};

const sendCreated = (res, payload = {}) => {
  sendSuccess(res, payload, 201);
};

const sendError = (res, message = 'Internal Server Error', statusCode = 500) => {
  res.status(statusCode).json({ success: false, error: message });
};

module.exports = { sendSuccess, sendCreated, sendError };
