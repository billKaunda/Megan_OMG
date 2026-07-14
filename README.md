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
- Original example contract: [contracts/AssessmentToken.sol](contracts/AssessmentToken.sol)
- Improved, production-oriented token: [contracts/ImprovedAssessmentToken.sol](contracts/ImprovedAssessmentToken.sol)
- Foundry test suite: [test/ImprovedAssessmentToken.t.sol](test/ImprovedAssessmentToken.t.sol)
- Foundry deploy script: [script/Deploy.s.sol](script/Deploy.s.sol)
- Node deploy wrapper: [scripts/deploy-contract.js](scripts/deploy-contract.js)
- Full engineering write-up: [SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md)

---

## Project Structure

```text
hometask-blockchain/
├── config/
├── controllers/
├── contracts/        # Solidity sources (original + improved token)
├── lib/              # Foundry dependencies (OpenZeppelin, forge-std) as submodules
├── middleware/
├── models/
├── routes/
├── script/           # Foundry deploy script (Deploy.s.sol)
├── scripts/          # Node deploy wrapper
├── services/
├── src/              # React frontend
├── test/             # Foundry Solidity tests
├── tests/            # JS backend tests
├── foundry.toml
├── package.json
├── server.js
└── README.md
```

---

## Getting Started

### Prerequisites
- Node.js 18+
- npm
- [Foundry](https://getfoundry.sh) — only needed to build, test, or deploy the smart
  contracts. The web app runs without it.

### Install

```bash
npm install

# Only if you plan to work on the contracts: fetch the pinned Solidity dependencies.
git submodule update --init --recursive
```

Solidity dependencies (OpenZeppelin, forge-std) are git submodules pinned to exact release
commits rather than floating versions, so contract builds are reproducible across machines.

### Configure environment

```bash
cp .env.example .env
```

[`.env.example`](.env.example) documents every supported variable — backend settings plus the
contract deployment keys — and the defaults run the web app out of the box. `.env` is
git-ignored; never commit real keys.

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

The original [contracts/AssessmentToken.sol](contracts/AssessmentToken.sol) is a simple,
hand-rolled ERC-20-style token kept in place for reference.

[contracts/ImprovedAssessmentToken.sol](contracts/ImprovedAssessmentToken.sol) is the
production-oriented rewrite. It is built on audited OpenZeppelin components and adds a
hard supply cap, owner-gated minting, burning, EIP-2612 permit (gasless approvals),
two-step ownership transfer, and custom errors — with full NatSpec. See
[SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) for the change-by-change rationale
(security benefit, gas benefit, trade-offs, and assumptions).

The rewrite fixes a real bug in the original: transfers to `address(0)` destroyed tokens
**without** reducing `totalSupply`, so supply permanently overstated circulation with no
recovery path. It is reproduced by a passing test in
[test/AssessmentToken.legacy.t.sol](test/AssessmentToken.legacy.t.sol).

### Trust model, in short

The owner may mint up to `cap` and nothing else — it cannot exceed the cap, freeze balances,
seize funds, pause transfers, or upgrade the contract. For a fully trustless fixed-supply
token, deploy with `cap == initialSupply` and call `renounceOwnership()`.

### Contract toolchain (Foundry)

Prerequisites: [Foundry](https://getfoundry.sh) (`forge`, `cast`) and, for a local
broadcast, `anvil`.

The [Makefile](Makefile) is the entry point for all contract work. Run `make` for the full
target list:

```bash
make install          # fetch pinned Solidity deps (submodules under lib/)
make build            # compile
make test             # full suite (32 tests)
make coverage         # coverage, excluding script/
make gas              # per-function gas report
make sizes            # runtime/initcode size vs the EIP-170 limit
make storage          # storage layout of both tokens
make ci               # what CI runs: fmt-check + build + test

# Deploy (dry-run by default)
cp .env.example .env  # then set PRIVATE_KEY / RPC / token params
make deploy-local     # simulate against localhost
make deploy-sepolia   # broadcast + verify on Etherscan
```

`make deploy-mainnet` refuses to run without an explicit `CONFIRM=yes`, since it spends real
funds irreversibly.

The equivalent `npm run contracts:*` scripts are kept for anyone already in the JS toolchain
— both call the same forge commands.

> `forge fmt` is configured in [foundry.toml](foundry.toml) to **ignore**
> `contracts/AssessmentToken.sol`. The original is the baseline the review refers to;
> reformatting it would invalidate that review's line references and the diff against the
> rewrite.

The Node wrapper validates configuration up front and delegates the on-chain work to the
Foundry script `script/Deploy.s.sol`, so deployments are reproducible across environments.

---

## Testing

### Smart contracts (Foundry) — 50 tests

```bash
make test
make coverage
```

- [test/ImprovedAssessmentToken.t.sol](test/ImprovedAssessmentToken.t.sol) — 24 tests
  covering deployment and constructor validation, transfers, allowances, mint/cap
  enforcement, burn, two-step ownership, EIP-2612 permit including expiry, plus fuzz
  properties for supply conservation and the cap.
- [test/AssessmentToken.legacy.t.sol](test/AssessmentToken.legacy.t.sol) — 8 characterisation
  tests asserting the **original** contract's behaviour as it actually is, defects included.
  They are executable proof for every claim in the review, so the flaws can be reproduced
  rather than taken on faith.
- [test/Deploy.t.sol](test/Deploy.t.sol) — 18 tests covering the deploy script's validation,
  whole-token→base-unit scaling, post-deploy invariants, and the overflow edge, plus fuzz
  over the config space. Deployment mistakes are unrecoverable (the cap is immutable), so
  the script is tested like the token.

Coverage is 100% lines/statements/functions on both contracts. `script/Deploy.s.sol` sits at
~41% lines / 81% branches: its validation and deployment logic is fully covered, while its
env-reading and broadcast path is not unit-tested by design — see the note at the top of
[test/Deploy.t.sol](test/Deploy.t.sol).

### Backend (Node)

A regression suite for the blockchain model is included in
[tests/blockchain.test.js](tests/blockchain.test.js).

```bash
npm test
```

Use `npm test` rather than a bare `node --test`: the latter now recurses into the vendored
Solidity dependencies under `lib/` and tries to run OpenZeppelin's own Hardhat suite. The
script scopes the runner to this project's tests.

> **Known failure:** both backend tests currently fail against the committed
> `models/blockchain.js` — a pre-existing test/implementation mismatch in the blockchain
> track, untouched by the smart contract work. See [Known Limitations](#known-limitations).

---

## Known Limitations

- The blockchain is still a simplified educational implementation, not a production-grade distributed ledger.
- Wallet generation is demonstration-oriented and does not yet implement a full signing workflow end-to-end in the UI.
- **Both backend tests in [tests/blockchain.test.js](tests/blockchain.test.js) fail against the
  committed `models/blockchain.js`.** This is pre-existing and belongs to the blockchain track;
  it was left as-is rather than silently rewritten, because in both cases the *implementation
  looks correct and the test encodes a weaker contract than the model actually enforces*:
  - `rejects unsigned transactions` — the model **does** reject the transaction, but throws
    `"Cannot add unsigned or invalid transaction to chain"`, which the test's `/signature/i`
    matcher does not match. The behaviour is right; the assertion is too literal.
  - `persists and restores blockchain state` — the fixture sets
    `tx.signature = 'signature-placeholder'`, assuming presence of a signature is sufficient.
    `Transaction.isValid()` performs real ECDSA verification, so a placeholder is correctly
    rejected and `addTransaction` throws.

  Deciding whether to relax the tests or reword the model's error is a blockchain-track
  judgement call about intent, so it is flagged here rather than assumed.
- The original [AssessmentToken.sol](contracts/AssessmentToken.sol) is intentionally simple and is retained
  as the review baseline; it is **not** the contract intended for deployment. Use
  [ImprovedAssessmentToken.sol](contracts/ImprovedAssessmentToken.sol).
- The rewrite does not fix the inherent ERC-20 `approve` race condition — no ERC-20 does.
  `permit` gives callers a way to avoid it. See
  [SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) §1.6.
- The token is deliberately non-upgradeable and non-pausable; the full list of trade-offs is
  in [SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) §4.
- `config/index.js` carries an unused `testpvk` key inherited from the original assessment
  scaffold. It is referenced nowhere and has been left untouched.

---

## License

One More Game
