# Smart Contract Review — `AssessmentToken` → `ImprovedAssessmentToken`

**Track:** Smart Contract Engineer
**Author:** Bill Kaunda

This document is the written half of the Smart Contract Engineer track. It reviews the
original [`contracts/AssessmentToken.sol`](contracts/AssessmentToken.sol) — its state,
events, and transfer flow — then explains what
[`contracts/ImprovedAssessmentToken.sol`](contracts/ImprovedAssessmentToken.sol) changes and
why.

Every defect described here is backed by a passing test in
[`test/AssessmentToken.legacy.t.sol`](test/AssessmentToken.legacy.t.sol), which asserts the
original's behaviour *as it actually is*. Claims about storage layout and contract size come
from `forge inspect` / `forge build --sizes`, not from reading the source. If a claim below
isn't proven by a test, it's marked as a judgement call.

---

## 1. The original contract

### 1.1 State

`forge inspect contracts/AssessmentToken.sol:AssessmentToken storage`:

| Slot | Name | Type | Notes |
|---:|---|---|---|
| 0 | `name` | `string` | Public storage, written once at deploy |
| 1 | `symbol` | `string` | Public storage, written once at deploy |
| 2 | `decimals` | `uint8` | Public storage, written once at deploy |
| 3 | `totalSupply` | `uint256` | Set in constructor, never changes afterwards |
| 4 | `balanceOf` | `mapping(address => uint256)` | The ledger |
| 5 | `allowance` | `mapping(address => mapping(address => uint256))` | Delegated-spend budgets |

Two observations about this layout:

**`name`, `symbol`, and `decimals` are mutable storage, not constants.** They are assigned at
their declaration and never written again, so they're morally immutable — but the compiler
doesn't know that. Each is a real SLOAD on every read, and each costs a storage write at
deploy. Marking them `constant` would move them into bytecode and make reads free. This is a
gas and intent issue, not a safety one: there is no setter, so they cannot actually change.

**`totalSupply` is set once and never maintained.** This is the root of the contract's most
serious bug (§1.4). The variable is treated as a deploy-time constant while `balanceOf` is
treated as a live ledger, and nothing keeps the two in agreement.

### 1.2 Events

The contract declares the two events ERC-20 requires, with correct `indexed` placement:

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

Emission is mostly correct. `transfer`, `transferFrom`, and `approve` each emit their event
on success, and the constructor emits `Transfer(address(0), msg.sender, totalSupply)` — the
standard convention signalling a mint, which lets indexers reconstruct supply from logs
alone. That detail is easy to miss and the original gets it right.

The one event-level wart is that `approve` emits `Approval` even when the spender is
`address(0)` (§1.5) — an integrator watching logs sees an allowance that can never be used.

### 1.3 Transfer flow

**`transfer(to, value)`** — check the caller's balance covers `value`, debit the caller,
credit `to`, emit `Transfer`, return `true`.

**`approve(spender, value)`** — overwrite `allowance[msg.sender][spender]` with `value`, emit
`Approval`, return `true`. Note *overwrite*, not adjust; this matters in §1.6.

**`transferFrom(from, to, value)`** — check `from`'s balance, check the caller's allowance
against `from`, then debit balance, credit `to`, decrement the allowance, emit `Transfer`,
return `true`.

The arithmetic is sound. The contract is on `^0.8.20`, so checked math reverts on overflow
and underflow — there is no unchecked block and no need for SafeMath. The balance `require`s
are technically redundant with checked math, but they buy a readable revert string, which is
a reasonable trade. `testFuzz_Legacy_TransferRevertsOnInsufficientBalance` fuzzes the
overdraft path across the whole `uint256` range above the supply and confirms it always
reverts.

Ordering is also correct: state is written before the event is emitted, and there are no
external calls anywhere in the contract, so there is no reentrancy surface to protect. Adding
a `nonReentrant` guard here would be cargo-culting.

Self-transfer is safe — `balanceOf[msg.sender] -= value` and `balanceOf[to] += value` are
sequential storage operations, so when `to == msg.sender` the balance round-trips to its
original value rather than being duplicated. This is a classic place where naive
implementations that cache balances in memory corrupt the ledger.
`test_Legacy_SelfTransferDoesNotCorruptBalance` pins it.

### 1.4 Defect: transfers to `address(0)` destroy tokens without burning them

`transfer` and `transferFrom` never check `to != address(0)`. Tokens sent there are
permanently unspendable, but `totalSupply` is not decremented.

The consequence is that **`totalSupply` silently overstates the circulating supply forever**.
The ERC-20 invariant `sum(balances) == totalSupply` technically still holds, but only if you
count an address nobody holds the key to. Anything that divides by `totalSupply` — market
cap, a pro-rata airdrop, quorum in a governance snapshot, a staking share calculation — reads
a number that no longer reflects reality, and there is no way to correct it.

Proven by `test_Legacy_TransferToZeroAddressStrandsTokensWithoutBurning`: after sending 100
tokens to `address(0)`, `totalSupply` is unchanged and `balanceOf(address(0)) == 100 ether`.
`test_Legacy_TransferFromToZeroAddressAlsoAllowed` shows `transferFrom` has the same hole.

**This is the single most important reason the rewrite exists.** It is not a style
preference — it's a permanently wrong number with no recovery path.

### 1.5 Defect: `approve` does not validate the spender

Approving `address(0)` succeeds and emits `Approval`. The allowance is unusable, so nothing
is stolen, but it's a silent no-op that pollutes the event log for anyone indexing
allowances. Proven by `test_Legacy_ApproveZeroAddressSpenderSucceeds`.

### 1.6 Defect: the ERC-20 approve race

`approve` overwrites the allowance rather than adjusting it. A spender who sees a pending
re-approval in the mempool can front-run it, spend the **old** allowance, and then spend the
**new** one — extracting `old + new` where the owner only ever intended `new`.

`test_Legacy_ApproveRaceAllowsSpendingOldAndNewAllowance` demonstrates it concretely: the
owner approves 100, then re-approves 20, and the spender walks away with 120.

This one deserves an honest caveat. **It is inherent to the ERC-20 standard, and OpenZeppelin
does not fix it either** — the rewrite is not immune. What the rewrite adds is an escape
hatch: `permit` (§2.3) issues an exact, nonce-bound, deadline-bound allowance, and because
each signature is single-use, the stale-approval replay isn't available. Callers who use
`permit` sidestep the race; callers who use bare `approve` still own it. Claiming otherwise
would be overselling the rewrite.

### 1.7 Defect: no access control and no supply levers

The original has no owner, no mint, and no burn. Supply is frozen at construction, and the
only path that reduces spendable supply is the buggy one in §1.4.

A fixed supply is a perfectly defensible design — but here it's *implicit*, arrived at by
omission rather than decision. There's no cap to reason about because there's no minting, and
no way to retire supply because there's no burn.

### 1.8 Minor: `require` strings over custom errors

`require(cond, "insufficient balance")` stores the string in bytecode and returns it ABI-
encoded. Custom errors (`error InsufficientBalance(...)`) are cheaper and carry structured
data a caller can decode. On `^0.8.20` custom errors are available and are the modern default.

### 1.9 What the original gets right

Worth stating plainly, since a review that only lists faults isn't a review:

- Correct event signatures with correct `indexed` fields.
- The `Transfer` from `address(0)` mint convention in the constructor.
- Checked arithmetic, with no unchecked blocks and no unnecessary SafeMath.
- State written before events; no external calls, so no reentrancy surface.
- Self-transfer handled correctly.
- Small and readable — 2,036 bytes runtime.

The contract is a clean, honest teaching implementation. Its problems are the ones you'd
expect from a hand-rolled ERC-20: the standard's sharp edges (§1.4, §1.6) are exactly what
audited libraries exist to absorb.

---

## 2. The rewrite

`ImprovedAssessmentToken` is built on OpenZeppelin v5.6.1 rather than hand-rolled. The
reasoning is that a bespoke ERC-20 has no upside — the accounting is entirely commodity
logic, and every line of it is a line that hasn't been audited. Inheriting from OZ buys the
zero-address checks, custom errors, and the `_update` hook that the extensions compose
through.

The cost is honest and worth naming: runtime size grows from **2,036 → 6,153 bytes** (~3x)
and the dependency surface grows from zero to a pinned submodule. For a token contract
deployed once, that trade is heavily favourable.

### 2.1 `ERC20Capped` — an explicit, immutable ceiling

Minting is owner-gated, so the cap is what bounds the trust placed in the owner: it is set at
construction, has no setter, and **not even the owner can exceed it**. This turns "trust the
owner not to inflate" into "the owner mathematically cannot inflate past N".

`testFuzz_MintNeverExceedsCap` fuzzes mint amounts across the full range and asserts the cap
holds or the call reverts.

### 2.2 `ERC20Burnable` — burning that actually burns

This is the direct fix for §1.4. Holders reduce supply through `burn`/`burnFrom`, which
decrement `totalSupply` correctly, while sending to `address(0)` now reverts with
`ERC20InvalidReceiver`. Intent and mechanism finally match: the destructive operation is
named, and the accidental one is blocked.

`test_BurnThenRemintUnderCap` covers the interaction with the cap — burning frees headroom,
so cap accounting tracks live supply rather than cumulative mints.

### 2.3 `ERC20Permit` (EIP-2612) — signature-based approvals

Lets a holder authorise a spender with an offline signature: no approve transaction, no ETH
needed for gas, and the spender can pay. As noted in §1.6, each signature is nonce-bound and
deadline-bound, so it also gives callers a way to avoid the approve race.

`test_Permit` builds the EIP-712 digest by hand and checks the allowance and nonce move;
`test_RevertWhen_PermitExpired` covers deadline enforcement.

### 2.4 `Ownable2Step` — ownership that can't be fat-fingered away

Plain `Ownable` transfers control in a single call: one typo'd address and the contract is
permanently ownerless, taking minting with it. `Ownable2Step` requires the recipient to call
`acceptOwnership`, which proves the address is controlled by someone who can transact before
it receives control.

`test_TwoStepOwnershipTransfer` asserts ownership does *not* move until accepted.

### 2.5 No implicit decimal scaling

The original constructor multiplied by `10**decimals` internally, so `initialSupply` meant
whole tokens — while every other amount in the ABI (`transfer`, `approve`) means base units.
Two different meanings for "amount" in one interface is a foot-gun.

The rewrite takes base units everywhere, with no hidden multiplication. Whole-token scaling
moves to the tooling boundary in [`script/Deploy.s.sol`](script/Deploy.s.sol), where
`TOKEN_CAP` and `TOKEN_INITIAL_SUPPLY` are human-friendly and scaled once, explicitly.

### 2.6 The `_update` override

```solidity
function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Capped)
{
    super._update(from, to, value);
}
```

This is required, not decorative. Both `ERC20` and `ERC20Capped` define `_update`, so
Solidity forces an explicit override to disambiguate. The body forwards to `super`, and C3
linearisation routes through `ERC20Capped._update` (cap enforcement) before `ERC20._update`
(the accounting). Because every mint, transfer, and burn funnels through this one hook, the
cap cannot be bypassed by any path.

Getting the inheritance order wrong here would silently disable cap enforcement — which is
why `testFuzz_MintNeverExceedsCap` exists rather than a single happy-path mint test.

### 2.7 `ZeroAmount` on mint

The only bespoke logic in the contract. A zero mint is a no-op that emits a misleading
`Transfer` event; rejecting it keeps the log honest. Everything else defers to OZ.

---

## 3. Trust model

State it plainly, because "who can do what to me" is the first question any integrator asks:

**The owner can:** mint up to `cap`; transfer ownership (two-step); renounce ownership.

**The owner cannot:** mint beyond `cap`; freeze, seize, or claw back balances; pause
transfers; change `name`, `symbol`, `decimals`, or `cap`; upgrade the contract — it is
non-upgradeable by construction, with no proxy and no delegatecall.

**For a fully trustless fixed-supply token:** deploy with `cap == initialSupply` and call
`renounceOwnership()`. Minting becomes permanently impossible and the token is inert. This
was a deliberate design goal — the trust in the owner should be *optional*, and removable in
one transaction.

---

## 4. Known limitations and trade-offs

Judgement calls, deliberately made:

- **No pause mechanism.** `ERC20Pausable` was considered and rejected. Freezing transfers is
  a large amount of trust to hand an owner, and for a token with no external integrations to
  protect it buys little. A token that can be frozen is a different product.
- **No `ERC20Votes`.** Governance checkpointing adds meaningful gas to every transfer. Add it
  when there's a governor to use it, not speculatively.
- **The approve race is not fixed** (§1.6), only side-steppable via `permit`. Inherent to
  ERC-20.
- **The owner is an EOA by default.** For anything with real value the owner should be a
  multisig or timelock. That's a deployment decision, not a contract one, which is why
  `TOKEN_OWNER` is configurable.
- **Not upgradeable.** Immutability is the point; the escape hatch is redeploy-and-migrate.
- **Fee-on-transfer / rebasing are not supported** and are not intended to be.
- **`_mint` in the constructor when `initialSupply_ == 0` is skipped**, so a zero-supply
  deploy emits no `Transfer`. Intentional — no tokens moved, so no event.
- **Rounding:** none. The token performs no division anywhere, so there are no rounding
  edges to reason about.

---

## 5. Verification

```bash
make test             # 50 tests: 24 on the rewrite, 8 on the original, 18 on the deploy script
make test-legacy      # just the 8 proving the original's defects
make coverage         # 100% lines/statements/functions on both contracts
make sizes
```

Coverage spans deployment and constructor validation, transfers, approve/`transferFrom`,
mint and cap enforcement, burn, two-step ownership, EIP-2612 permit including expiry, and
fuzz properties (supply conservation across transfers, cap never exceeded on mint, scaling
across the config space).

The legacy suite is the part I'd point at in an interview: it's what turns "the original has a
zero-address bug" from an assertion into something the reader can run.

### A note on testing the deploy script

Writing [`test/Deploy.t.sol`](test/Deploy.t.sol) surfaced a design problem worth recording.
The script originally read its config from environment variables inside `run()`, which made it
effectively untestable: Foundry's env is process-global and its test runner is parallel, so
driving the script via `vm.setEnv` raced with every other test. Repeated `forge test` runs
failed 6, then 4, then 3 tests, with one test's fuzzed `TOKEN_CAP` surfacing in another's
assertions.

Moving the setup into `setUp()` does not fix it — Foundry runs `setUp` once, snapshots EVM
state, and reverts to the snapshot per test, while `vm.setEnv` mutates state outside the EVM
and is never rolled back. `--threads 1` fixes it, but only when someone remembers the flag,
and `threads = 1` in `foundry.toml` is accepted by `forge config` while not actually
serialising the runner — so a bare `forge test` stays flaky.

Rather than ship a suite that needs a flag to be correct, the script was refactored so that
`readConfig` (the only env reader) is separate from `validate` and `deployToken`, which take
an explicit `TokenConfig`. The tests drive the latter two and touch no global state, so the
suite is deterministic at any thread count. The env/broadcast path is left to
`make deploy-local`. Untestable code is usually a design signal, not a testing problem.

---

## 6. Deployment

Config comes from the environment, so the same script targets local, testnet, and mainnet
without edits. See [`.env.example`](.env.example).

```bash
make deploy-local                  # dry-run simulation, no broadcast
make deploy-sepolia                # broadcast + verify on Etherscan
make deploy-mainnet CONFIRM=yes    # guarded: refuses without the explicit confirmation
```

[`script/Deploy.s.sol`](script/Deploy.s.sol) validates config and fails fast *before* spending
gas, scales whole tokens to base units, then asserts on-chain state matches intent
(`cap`, `totalSupply`, `owner`) after broadcast — so a partial or misconfigured deploy fails
loudly instead of leaving a wrong-but-live token.

[`scripts/deploy-contract.js`](scripts/deploy-contract.js) wraps `forge script` so deployment
fits this repo's npm-centric ergonomics. It replaces the original script, which imported
`hardhat` — a package that was never in `package.json`, so it could not ever have run.
