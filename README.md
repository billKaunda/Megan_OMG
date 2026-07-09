# Blockchain Explorer and Smart Contract Demo

This repository is a compact full-stack demo for exploring blockchain concepts, interacting with a simplified chain, and reviewing a basic Solidity token contract.

It combines:
- a layered Express backend for a simplified blockchain
- a React-based explorer for interacting with the chain
- a Solidity smart contract example for assessment and deployment discussion
- a persistence layer so the chain can survive restarts

---

## What’s Included

### Backend
- Express API with routes for chain, transactions, mining, balance, stats, and wallets
- Blockchain domain model with block hashing, transaction validation, and mining logic
- Persistence layer that saves blockchain state to a JSON file
- Centralized middleware for error handling, logging, validation, and rate limiting

### Frontend
- React dashboard to inspect blockchain state and mine blocks
- Wallet creation panel for generating key material and checking balances
- Transaction form for creating pending transactions
- Polling-based refresh for near-real-time updates

### Smart Contracts
- Solidity contract example in [contracts/AssessmentToken.sol](contracts/AssessmentToken.sol)
- Deployment script in [scripts/deploy-contract.js](scripts/deploy-contract.js)

---

## Project Structure

```text
hometask-blockchain/
├── config/
├── controllers/
├── contracts/
├── middleware/
├── models/
├── routes/
├── scripts/
├── services/
├── src/
├── tests/
├── package.json
├── server.js
└── README.md
```

---

## Getting Started

### Prerequisites
- Node.js 18+
- npm

### Install

```bash
npm install
```

### Configure environment

```bash
cp .env.example .env
```

If you do not have an .env.example file yet, create one with values such as:

```env
PORT=3002
NODE_ENV=development
BLOCKCHAIN_DIFFICULTY=2
BLOCKCHAIN_MINING_REWARD=100
INITIAL_MINER_ADDRESS=genesis-miner
SEED_DEMO_DATA=true
REACT_APP_API_URL=http://localhost:3002
```

### Run the app

```bash
# Terminal 1
npm start

# Terminal 2
npm run dev
```

The React app uses the proxy in [src/setupProxy.js](src/setupProxy.js) so browser requests to /api are forwarded to the backend.

---

## API Overview

All API responses follow this pattern:

```json
{ "success": true, "message": "...", ... }
```

### Core endpoints

| Method | Path | Description |
|---|---|---|
| GET | /api/chain | Return the full blockchain |
| GET | /api/chain/valid | Return whether the chain is valid |
| POST | /api/transactions | Add a pending transaction |
| GET | /api/transactions/pending | View pending transactions |
| POST | /api/mine | Mine the pending transactions |
| GET | /api/balance/:address | Get an address balance |
| GET | /api/stats | View chain and mining statistics |
| POST | /api/wallets | Generate a wallet-like key pair |
| GET | /api/wallets/:address | View a balance for a wallet address |

---

## Smart Contract Notes

The Solidity contract in [contracts/AssessmentToken.sol](contracts/AssessmentToken.sol) is a simple ERC-20-style token example. It demonstrates:
- token supply initialization
- balance tracking
- transfer and approval flows
- basic events

It is intended as an assessment artifact and can be extended for more advanced scenarios.

---

## Testing

A basic regression suite is included in [tests/blockchain.test.js](tests/blockchain.test.js).

Run:

```bash
node --test
```

---

## Known Limitations

- The blockchain is still a simplified educational implementation, not a production-grade distributed ledger.
- Wallet generation is demonstration-oriented and does not yet implement a full signing workflow end-to-end in the UI.
- The smart contract is intentionally simple for assessment purposes.

---

## License

One More Game
