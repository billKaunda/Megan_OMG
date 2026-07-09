const fs = require('fs');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const portFile = path.resolve(__dirname, '..', '.server-port');

const getApiTarget = () => {
  if (fs.existsSync(portFile)) {
    const storedPort = fs.readFileSync(portFile, 'utf8').trim();
    if (storedPort) {
      return `http://localhost:${storedPort}`;
    }
  }

  return process.env.REACT_APP_API_URL || process.env.API_URL || 'http://localhost:3002';
};

module.exports = function (app) {
  app.use(
    '/api',
    createProxyMiddleware({
      target: getApiTarget(),
      changeOrigin: true,
    })
  );
};
