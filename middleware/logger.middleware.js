const morgan = require('morgan');
const config = require('../config');

// Use concise format in development, Apache combined log in production
const format = config.env === 'production' ? 'combined' : 'dev';

module.exports = morgan(format);
