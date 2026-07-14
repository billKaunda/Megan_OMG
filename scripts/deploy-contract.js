#!/usr/bin/env node
/**
 * @file deploy-contract.js
 * @summary Production-grade deployment wrapper for {ImprovedAssessmentToken}.
 *
 * @description
 * The original version of this script imported `hardhat`, which was never a
 * dependency of this project — so it could not run. The contract toolchain is
 * now Foundry, and the canonical deployment logic (config parsing, decimal
 * scaling, on-chain invariant checks) lives in `script/Deploy.s.sol`.
 *
 * This Node script is a thin, well-documented orchestration layer around
 * `forge script`. It exists so that deployment fits naturally into this
 * JavaScript-centric repo (single `.env`, `npm run` ergonomics, CI parity)
 * while the actual on-chain work stays in a single, testable Solidity script.
 *
 * Responsibilities:
 *   1. Load and validate configuration from `.env` BEFORE spending any gas.
 *   2. Verify the Foundry toolchain and required secrets are present.
 *   3. Resolve the target network to an RPC URL and (optionally) enable
 *      Etherscan source verification.
 *   4. Invoke `forge script` with the correct, reproducible flags.
 *   5. Surface clear, actionable errors and correct process exit codes.
 *
 * @example
 *   # Local dry-run (simulation, no broadcast):
 *   node scripts/deploy-contract.js --network localhost
 *
 *   # Broadcast to a testnet and verify on Etherscan:
 *   node scripts/deploy-contract.js --network sepolia --broadcast --verify
 */

'use strict';

const { spawnSync, execSync } = require('node:child_process');
const path = require('node:path');

require('dotenv').config();

/** Networks this script knows how to deploy to, mapped to their env RPC var. */
const NETWORKS = Object.freeze({
  localhost: { rpcEnv: null, chainId: 31337, verifiable: false },
  sepolia: { rpcEnv: 'SEPOLIA_RPC_URL', chainId: 11155111, verifiable: true },
  mainnet: { rpcEnv: 'MAINNET_RPC_URL', chainId: 1, verifiable: true },
});

const SCRIPT_TARGET = 'script/Deploy.s.sol:Deploy';

/**
 * Parse `--flag value` / `--flag` style CLI arguments into a plain object.
 * @param {string[]} argv - Raw `process.argv.slice(2)`.
 * @returns {{network: string, broadcast: boolean, verify: boolean}}
 */
function parseArgs(argv) {
  const opts = { network: 'localhost', broadcast: false, verify: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--network':
        opts.network = argv[(i += 1)];
        break;
      case '--broadcast':
        opts.broadcast = true;
        break;
      case '--verify':
        opts.verify = true;
        break;
      case '-h':
      case '--help':
        printUsageAndExit(0);
        break;
      default:
        fail(`Unknown argument: ${arg}. Use --help for usage.`);
    }
  }
  return opts;
}

/** Print usage text and terminate. @param {number} code - Exit code. */
function printUsageAndExit(code) {
  process.stdout.write(
    [
      'Usage: node scripts/deploy-contract.js [options]',
      '',
      'Options:',
      '  --network <name>   Target network: localhost | sepolia | mainnet (default: localhost)',
      '  --broadcast        Actually send the deployment transaction (omit for a dry-run)',
      '  --verify           Verify source on Etherscan after deployment',
      '  -h, --help         Show this help',
      '',
      'Required env (.env):',
      '  PRIVATE_KEY                    Deployer private key',
      '  SEPOLIA_RPC_URL / MAINNET_RPC_URL   RPC endpoint for the chosen network',
      '  ETHERSCAN_API_KEY             Required only when --verify is used',
      '',
      'Optional token config (.env): TOKEN_NAME, TOKEN_SYMBOL, TOKEN_CAP,',
      '  TOKEN_INITIAL_SUPPLY, TOKEN_OWNER (see .env.example).',
      '',
    ].join('\n'),
  );
  process.exit(code);
}

/** Print an error and exit non-zero. @param {string} message */
function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

/** Ensure the `forge` binary is available on PATH. */
function assertForgeInstalled() {
  try {
    execSync('forge --version', { stdio: 'ignore' });
  } catch {
    fail('Foundry (`forge`) is not installed or not on PATH. Install: https://getfoundry.sh');
  }
}

/**
 * Validate configuration and build the argument vector for `forge script`.
 * @param {{network: string, broadcast: boolean, verify: boolean}} opts
 * @returns {string[]} Arguments to pass to `forge`.
 */
function buildForgeArgs(opts) {
  const net = NETWORKS[opts.network];
  if (!net) {
    fail(`Unsupported network "${opts.network}". Supported: ${Object.keys(NETWORKS).join(', ')}.`);
  }

  if (!process.env.PRIVATE_KEY) {
    fail('PRIVATE_KEY is not set. Add it to your .env (see .env.example).');
  }

  const args = ['script', SCRIPT_TARGET, '-vvvv'];

  // Resolve the RPC endpoint. localhost uses the Anvil default; others require env.
  if (net.rpcEnv) {
    const rpcUrl = process.env[net.rpcEnv];
    if (!rpcUrl) {
      fail(`${net.rpcEnv} is not set but is required to deploy to "${opts.network}".`);
    }
    args.push('--rpc-url', rpcUrl);
  } else {
    args.push('--rpc-url', 'http://127.0.0.1:8545');
  }

  if (opts.broadcast) args.push('--broadcast');

  if (opts.verify) {
    if (!net.verifiable) {
      fail(`Network "${opts.network}" does not support Etherscan verification.`);
    }
    if (!process.env.ETHERSCAN_API_KEY) {
      fail('--verify requires ETHERSCAN_API_KEY in your .env.');
    }
    args.push('--verify');
  }

  return args;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  assertForgeInstalled();

  const args = buildForgeArgs(opts);
  const mode = opts.broadcast ? 'BROADCAST' : 'DRY-RUN (simulation)';

  // foundry.toml interpolates these in its [etherscan]/[rpc_endpoints] sections
  // and treats a missing variable as fatal — even for networks that don't need
  // them. Validation above already enforced whatever THIS deployment requires,
  // so default the rest to empty strings purely to keep config parsing happy.
  process.env.ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
  process.env.SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || '';
  process.env.MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || '';

  console.log(`\n▶ Deploying ImprovedAssessmentToken`);
  console.log(`  network : ${opts.network} (chainId ${NETWORKS[opts.network].chainId})`);
  console.log(`  mode    : ${mode}`);
  console.log(`  verify  : ${opts.verify ? 'yes' : 'no'}\n`);

  // Inherit stdio so forge's rich, colourised output streams straight through.
  const result = spawnSync('forge', args, {
    stdio: 'inherit',
    cwd: path.resolve(__dirname, '..'),
    env: process.env,
  });

  if (result.error) fail(`Failed to launch forge: ${result.error.message}`);
  if (result.status !== 0) fail(`Deployment failed (forge exited with code ${result.status}).`);

  console.log('\n✔ Deployment script completed successfully.\n');
}

main();
