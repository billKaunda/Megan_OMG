# Reviewer Guide — Smart Contract Engineer Track

**Candidate:** Bill Kaunda
**Repository:** https://github.com/billKaunda/Megan_OMG
**Track:** Smart Contract Engineer

A run-through of the contract work: setup, commands, and how to see it working. Every command
and every output below was executed against this repo — nothing here is illustrative.

**In a hurry?** Three commands reproduce the core result:

```bash
git submodule update --init --recursive
make test        # 50 passing tests
make coverage    # 100% on both contracts
```

Companion documents:
- [SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) — the engineering write-up: the
  original contract's state/events/transfer flow, each defect found, the trust model, and
  the trade-offs. **This is the main deliverable for the track.**
- [README.md](README.md) — project-wide documentation.

---

## 1. What was built

The assessment supplied [`contracts/AssessmentToken.sol`](contracts/AssessmentToken.sol), a
hand-rolled ERC-20. It is **left untouched** as the review baseline.

[`contracts/ImprovedAssessmentToken.sol`](contracts/ImprovedAssessmentToken.sol) is the
rewrite, built on OpenZeppelin v5.6.1:

| Feature | Why |
|---|---|
| `ERC20Capped` | Immutable supply ceiling the owner cannot exceed — bounds the trust in minting |
| `ERC20Burnable` | Burning that actually decrements `totalSupply` |
| `ERC20Permit` | EIP-2612 gasless approvals; also lets callers sidestep the approve race |
| `Ownable2Step` | Recipient must accept ownership, so it can't be fat-fingered away |

### The headline finding

The original's `transfer`/`transferFrom` never check `to != address(0)`. Tokens sent there are
unrecoverable, but `totalSupply` is **not** decremented — so supply permanently overstates
circulation, with no recovery path. Anything dividing by `totalSupply` (market cap, a pro-rata
airdrop, governance quorum) reads a permanently wrong number.

This is proven, not asserted — see [§5](#5-the-legacy-suite-proving-the-original-is-broken).

---

## 2. Setup

### 2.1 Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

This installs to `~/.foundry/bin`. If `forge` isn't found afterwards, that directory isn't on
your `PATH` for non-interactive shells — the [Makefile](Makefile) prepends it, so `make`
targets work regardless.

### 2.2 Clone and fetch pinned dependencies

```bash
git clone https://github.com/billKaunda/Megan_OMG.git
cd Megan_OMG
git submodule update --init --recursive     # or: make install
```

### 2.3 Pinned versions

Solidity dependencies are git submodules pinned to exact release tags, not floating ranges, so
builds are reproducible:

| Dependency | Version | Commit |
|---|---|---|
| `openzeppelin-contracts` | **v5.6.1** | `5fd1781b1454fd1ef8e722282f86f9293cacf256` |
| `forge-std` | **v1.16.2** | `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b` |

Verify with `git submodule status`.

The compiler is pinned in [foundry.toml](foundry.toml) rather than floated, so the reviewer's
`forge` version does not change the bytecode:

```toml
solc = "0.8.28"
evm_version = "cancun"
optimizer = true
optimizer_runs = 10_000     # tuned for a deploy-once, call-often token
```

`forge build` fetches `solc 0.8.28` automatically. No global toolchain setup needed.

> **Toolchain:** built and verified on upstream (vanilla) Foundry — `forge 1.5.1-stable`,
> commit `b0a9dd9`. Everything targets vanilla EVM (`cancun`). Because `solc` is pinned in
> [foundry.toml](foundry.toml), a different `forge` version still produces identical bytecode:
> `AssessmentToken` 2,036 B and `ImprovedAssessmentToken` 6,153 B on any recent build.

### 2.4 Environment

The contract work needs **no `.env` for building or testing**. It's only needed to deploy:

```bash
cp .env.example .env
```

[`.env.example`](.env.example) documents every variable. Its default `PRIVATE_KEY` is Anvil's
well-known account #0 — public, worthless, and safe to use locally. `.env` is git-ignored.

---

## 3. Running it

`make` with no arguments lists every target. The Makefile is the entry point; equivalent
`npm run contracts:*` scripts exist for the JS toolchain and call the same commands.

| Command | Raw equivalent | Purpose |
|---|---|---|
| `make build` | `forge build` | Compile |
| `make test` | `forge test` | Full suite (50 tests) |
| `make coverage` | `forge coverage` | Coverage report |
| `make gas` | `forge test --gas-report` | Per-function gas |
| `make sizes` | `forge build --sizes` | Size vs the EIP-170 limit |
| `make storage` | `forge inspect ... storage` | Storage layout of both tokens |
| `make ci` | — | `fmt-check` + `build` + `test` |

### Contract sizes (`make sizes`)

```
| Contract                | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) |
| AssessmentToken         | 2,036            | 2,950             | 22,540             |
| ImprovedAssessmentToken | 6,153            | 8,089             | 18,423             |
```

The ~3x growth is the honest cost of inheriting audited code — a trade worth naming, and one
[SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) §2 argues for explicitly.

---

## 4. Tests — 50 passing

```bash
make test
```

```
Ran 3 test suites: 50 tests passed, 0 failed, 0 skipped (50 total tests)
```

| Suite | Tests | Covers |
|---|---:|---|
| [`ImprovedAssessmentToken.t.sol`](test/ImprovedAssessmentToken.t.sol) | 24 | Deployment, transfers, allowances, mint/cap, burn, 2-step ownership, EIP-2612 permit |
| [`AssessmentToken.legacy.t.sol`](test/AssessmentToken.legacy.t.sol) | 8 | The **original's** real behaviour — defects included |
| [`Deploy.t.sol`](test/Deploy.t.sol) | 18 | Deploy script validation, scaling, invariants |

Run individually:

```bash
make test-improved      # 24
make test-legacy        #  8
make test-deploy        # 18
make test-match m=Permit
make test-v             # full suite with traces
```

### Fuzz tests

`[fuzz] runs = 512` in [foundry.toml](foundry.toml) — each property below runs 512 randomised
cases per invocation:

| Fuzz test | Property |
|---|---|
| `testFuzz_TransferPreservesTotalSupply` | Transfers conserve supply |
| `testFuzz_MintNeverExceedsCap` | Cap holds or the call reverts, for any amount |
| `testFuzz_Legacy_TransferRevertsOnInsufficientBalance` | Original's overdraft path always reverts |
| `testFuzz_DeployToken_ScalingHoldsForAnyValidConfig` | 1e18 scaling holds across the config space |
| `testFuzz_DeployToken_AnyValidOwnerReceivesSupply` | Any non-zero owner receives the full supply |

### Coverage (`make coverage`)

```
| File                                  | % Lines         | % Statements    | % Branches     | % Funcs        |
| contracts/AssessmentToken.sol         | 100.00% (22/22) | 100.00% (18/18) | 66.67% (4/6)   | 100.00% (4/4)  |
| contracts/ImprovedAssessmentToken.sol | 100.00% (10/10) | 100.00% (10/10) | 100.00% (2/2)  | 100.00% (4/4)  |
| script/Deploy.s.sol                   | 41.18% (14/34)  | 41.18% (14/34)  | 81.25% (13/16) | 40.00% (2/5)   |
```

**100% lines/statements/functions on both contracts.** `Deploy.s.sol`'s uncovered remainder is
its env-reading and broadcast path, deliberately not unit-tested — see [§7](#7-design-notes).

### Gas regressions

`.gas-snapshot` is committed, so `make snapshot-check` fails on unintended gas changes.

---

## 5. The legacy suite: proving the original is broken

```bash
make test-legacy
```

A review that says "the original has a zero-address bug" is an assertion. These 8 tests make it
reproducible — they assert the original's behaviour *as it actually is*, defects included:

- `test_Legacy_TransferToZeroAddressStrandsTokensWithoutBurning` — sends 100 tokens to
  `address(0)`; `totalSupply` is unchanged and the tokens sit unspendable at the zero address.
- `test_Legacy_ApproveRaceAllowsSpendingOldAndNewAllowance` — owner approves 100, re-approves
  20, spender extracts **120**.
- `test_Legacy_ApproveZeroAddressSpenderSucceeds` — an unusable allowance that still emits
  `Approval`.

Paired with the rewrite's fixes: `test_RevertWhen_TransferToZeroAddress` shows the same call now
reverting with `ERC20InvalidReceiver`.

> **On the approve race:** the rewrite does **not** fix it, and neither does OpenZeppelin — it is
> inherent to ERC-20. `permit` gives callers a way to avoid it. Claiming a fix would be
> overselling the rewrite; see [SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) §1.6.

---

## 6. Deploying against Anvil

### 6.1 Start a local node

```bash
make anvil       # or: anvil
```

Listens on `127.0.0.1:8545`, chain ID `31337`, with funded accounts.

### 6.2 Deploy (in a second terminal)

```bash
cp .env.example .env

make deploy-local                                       # simulation, no broadcast
node scripts/deploy-contract.js --network localhost --broadcast    # actually send
```

Real output from the broadcast run:

```
▶ Deploying ImprovedAssessmentToken
  network : localhost (chainId 31337)
  mode    : BROADCAST

  === ImprovedAssessmentToken deployed ===
  chain id       : 31337
  address        : 0x5FbDB2315678afecb367f032d93F642f64180aa3
  owner / holder : 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  name / symbol  : Assessment Token AST
  cap (whole)    : 1000000
  initial (whole): 100000

✔ Deployment script completed successfully.
```

Or drive `forge script` directly, bypassing the Node wrapper:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
```

`make deploy-mainnet` refuses to run without an explicit `CONFIRM=yes` — real funds,
irreversible, and one typo away from `deploy-sepolia`.

### 6.3 Verify the live contract with `cast`

Against the deployed address above:

```bash
export T=0x5FbDB2315678afecb367f032d93F642f64180aa3
export R="--rpc-url http://127.0.0.1:8545"

cast call $T 'name()(string)'        $R    # "Assessment Token"
cast call $T 'symbol()(string)'      $R    # "AST"
cast call $T 'decimals()(uint8)'     $R    # 18
cast call $T 'cap()(uint256)'        $R    # 1000000000000000000000000  [1e24]
cast call $T 'totalSupply()(uint256)' $R   # 100000000000000000000000   [1e23]
cast call $T 'owner()(address)'      $R    # 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
cast call $T 'mintableRemaining()(uint256)' $R  # 900000000000000000000000 [9e23]
```

Note `cap = 1e24` and `totalSupply = 1e23` — the env supplied whole tokens (`1000000`,
`100000`) and the deploy layer scaled them by 1e18. That boundary is the script's core job.

**A transfer:**

```bash
export PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export ALICE=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

cast send $T "transfer(address,uint256)" $ALICE 1000000000000000000000 --private-key $PK $R
cast call $T "balanceOf(address)(uint256)" $ALICE $R
# 1000000000000000000000 [1e21]   ← 1,000 AST
```

**The original's bug, now fixed** — this is the whole point of the rewrite:

```bash
cast send $T "transfer(address,uint256)" 0x0000000000000000000000000000000000000000 1 \
  --private-key $PK $R
```

```
execution reverted: custom error 0xec442f05:
ERC20InvalidReceiver(0x0000000000000000000000000000000000000000)
```

The original silently accepted this and stranded the tokens.

**Access control:**

```bash
# Account #1 (not the owner) attempts to mint
cast send $T "mint(address,uint256)" $ALICE 1 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d $R
```

```
execution reverted:
OwnableUnauthorizedAccount(0x70997970C51812dc3A010C7d01b50e0d17dc79C8)
```

---

## 7. Design notes

Three decisions worth explaining, since they're the ones I'd expect questions about.

### Why rebuild on OpenZeppelin

A bespoke ERC-20 has no upside: the accounting is commodity logic, and every hand-written line
is a line that hasn't been audited. Inheriting buys the zero-address checks, custom errors, and
the `_update` hook the extensions compose through. The cost — ~3x bytecode, plus a dependency —
is real and named in the review rather than glossed over.

### Why `Deploy.s.sol` separates config from deployment

The script originally read env inline in `run()`, which made it untestable. Foundry's env is
process-global and its test runner is parallel, so driving it via `vm.setEnv` raced with every
other test: repeated `forge test` runs failed 6, then 4, then 3 tests, with one test's fuzzed
`TOKEN_CAP` surfacing in another's assertions.

Two fixes that look right but aren't: a baseline in `setUp()` (Foundry snapshots EVM state and
reverts per test, but `vm.setEnv` mutates state *outside* the EVM, so it's never rolled back),
and `threads = 1` in `foundry.toml` (accepted by `forge config`, but it doesn't serialise the
runner — only the `--threads 1` CLI flag does).

Hiding `--threads 1` in the Makefile would mean shipping a suite that's only correct when
someone remembers a flag. Instead `readConfig` (the only env reader) was separated from
`validate` and `deployToken`, which take an explicit `TokenConfig`. The tests drive those two
and touch no global state. **Bare `forge test` now passes 50/50 at full parallelism.**
Untestable code is usually a design signal, not a testing problem.

### Why `forge fmt` ignores `AssessmentToken.sol`

[foundry.toml](foundry.toml) has `[fmt] ignore = ["contracts/AssessmentToken.sol"]`. The
original is the baseline the review's line references point at; reformatting it would invalidate
both the review and the diff against the rewrite.

---

## 8. Known limitations

Stated plainly — these are deliberate, not oversights.

**Contract scope**
- **No pause mechanism.** `ERC20Pausable` was considered and rejected: freezing transfers is a
  lot of trust to hand an owner, and a token that can be frozen is a different product.
- **No `ERC20Votes`.** Checkpointing costs gas on every transfer. Add it when a governor exists.
- **The approve race is not fixed** — inherent to ERC-20; `permit` sidesteps it.
- **Owner is an EOA by default.** For real value it should be a multisig/timelock — a deployment
  decision, which is why `TOKEN_OWNER` is configurable.
- **Not upgradeable.** Immutability is the point; the escape hatch is redeploy-and-migrate.

The full list, with reasoning, is in [SMART_CONTRACT_REVIEW.md](SMART_CONTRACT_REVIEW.md) §4.

**Outside this track — flagged, not fixed**

- **Two backend tests fail** (`npm test`), pre-existing and untouched by this work. In both
  cases the implementation is correct and the test encodes a weaker contract: one asserts
  `/signature/i` against a model that throws `"Cannot add unsigned or invalid transaction to
  chain"`, and the other uses a placeholder signature that real ECDSA verification correctly
  rejects. Both belong to the Blockchain track; rewriting another track's tests seemed a worse
  call than reporting them. Detail in [README.md](README.md) → Known Limitations.
- **`config/index.js:19`** carries an unused `testpvk` key from the original scaffold: a
  char-code array that base64-decodes to a `jsonkeeper.com` URL. It is referenced nowhere, so I
  left it untouched and did not fetch it — but a key named like a private key, obfuscated twice
  and reachable from committed code, seemed worth surfacing rather than silently deleting.

---

## 9. File map

| Path | What |
|---|---|
| [`contracts/AssessmentToken.sol`](contracts/AssessmentToken.sol) | Original — untouched baseline |
| [`contracts/ImprovedAssessmentToken.sol`](contracts/ImprovedAssessmentToken.sol) | The rewrite |
| [`test/ImprovedAssessmentToken.t.sol`](test/ImprovedAssessmentToken.t.sol) | 24 tests |
| [`test/AssessmentToken.legacy.t.sol`](test/AssessmentToken.legacy.t.sol) | 8 tests proving the original's defects |
| [`test/Deploy.t.sol`](test/Deploy.t.sol) | 18 tests on the deploy script |
| [`script/Deploy.s.sol`](script/Deploy.s.sol) | Foundry deploy script |
| [`scripts/deploy-contract.js`](scripts/deploy-contract.js) | Node wrapper around `forge script` |
| [`Makefile`](Makefile) | Contract entry point (`make` to list targets) |
| [`foundry.toml`](foundry.toml) | Pinned solc, optimizer, fuzz config |
| [`SMART_CONTRACT_REVIEW.md`](SMART_CONTRACT_REVIEW.md) | **The main write-up** |
