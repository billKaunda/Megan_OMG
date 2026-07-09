const express = require("express");
const fs = require("fs");
const path = require("path");
const net = require("net");

const config = require("./config");
const logger = require("./utils/logger");

const corsMiddleware = require("./middleware/cors.middleware");
const requestLogger = require("./middleware/logger.middleware");
const errorHandler = require("./middleware/errorHandler.middleware");
const notFound = require("./middleware/notFound.middleware");
const { apiLimiter } = require("./middleware/rateLimit.middleware");

const apiRoutes = require("./routes");
const healthRoutes = require("./routes/health.routes");
const app = express();
const portFile = path.join(__dirname, ".server-port");

const writePortFile = (port) => {
  fs.writeFileSync(portFile, String(port), "utf8");
};

const getAvailablePort = (startPort) =>
  new Promise((resolve, reject) => {
    const tester = net.createServer();

    tester.once("error", (error) => {
      if (error.code === "EADDRINUSE") {
        resolve(getAvailablePort(startPort + 1));
      } else {
        reject(error);
      }
    });

    tester.once("listening", () => {
      const address = tester.address();
      tester.close(() => resolve(address.port));
    });

    tester.listen(startPort, "127.0.0.1");
  });

// ── Global middleware ──────────────────────────────────────────────────────────
app.use(corsMiddleware);
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(requestLogger);

// ── Health check (no rate limit, no auth) ─────────────────────────────────────
app.use("/health", healthRoutes);

// ── API routes ─────────────────────────────────────────────────────────────────
app.use("/api", apiLimiter, apiRoutes);

// ── Static build (production) ──────────────────────────────────────────────────
app.use(express.static(path.join(__dirname, "build")));

app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "build", "index.html"));
});

// ── Error handling (must be last) ──────────────────────────────────────────────
app.use(notFound);
app.use(errorHandler);

// ── Start server ───────────────────────────────────────────────────────────────
const startServer = async () => {
  const preferredPort = Number.parseInt(process.env.PORT || config.port, 10) || 3002;
  const portToUse = await getAvailablePort(preferredPort);
  process.env.PORT = String(portToUse);
  writePortFile(portToUse);

  const server = app.listen(portToUse, () => {
    logger.sysinfo(`Environment : ${config.env}`);
    logger.info(`Server      : http://localhost:${portToUse}`);
    logger.info(`API         : http://localhost:${portToUse}/api`);
  });

  server.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      logger.error(`Port ${portToUse} is still unavailable.`);
      logger.error("The app will exit so you can choose a different port manually if needed.");
      process.exit(1);
    } else {
      throw err;
    }
  });

  return server;
};

startServer().catch((err) => {
  logger.error(`Failed to start server: ${err.message}`);
  process.exit(1);
});

module.exports = app;
