// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title ImprovedAssessmentToken
 * @author Bill Kaunda
 * @notice A capped, mintable, burnable ERC-20 token with EIP-2612 permit support.
 * @dev This is the improved version of the original hand-rolled `AssessmentToken`.
 *      It has been rebuilt on top of audited OpenZeppelin components to inherit
 *      their correctness, custom errors, and security properties, then extended
 *      with a small, deliberately scoped set of production-oriented features:
 *
 *      - {ERC20}          — canonical, audited transfer/approve accounting.
 *      - {ERC20Capped}    — a hard, immutable supply ceiling that even the owner
 *                           cannot exceed, bounding the trust placed in minting.
 *      - {ERC20Burnable}  — holders can burn their own balance (and approved allowances).
 *      - {ERC20Permit}    — gasless, signature-based approvals (EIP-2612), which
 *                           improve UX and let a spender pay the approval gas.
 *      - {Ownable2Step}   — two-step ownership transfer to prevent accidentally
 *                           handing control to an unrecoverable address.
 *
 *      Amounts are always denominated in the token's smallest unit (18 decimals),
 *      consistent with how ERC-20 balances are stored on-chain. Any human-readable
 *      "whole token" scaling is the responsibility of the caller / deployment
 *      tooling, which keeps this contract free of hidden multiplication footguns.
 *
 *      Trust model: the owner may mint new tokens up to {cap}. It cannot mint
 *      beyond the cap, cannot freeze balances, and cannot seize funds. For a fully
 *      trustless fixed-supply token, deploy with `cap == initialSupply` and call
 *      {renounceOwnership} so no further minting is ever possible.
 */
contract ImprovedAssessmentToken is ERC20, ERC20Burnable, ERC20Capped, ERC20Permit, Ownable2Step {
    /// @notice Thrown when an operation is called with a zero token amount that would be a no-op.
    error ZeroAmount();

    /**
     * @notice Deploys the token, sets the supply cap, and mints the initial supply.
     * @dev Input validation is delegated to the audited OpenZeppelin parents:
     *      - `cap_ == 0`             reverts with {ERC20Capped-ERC20InvalidCap}.
     *      - `initialSupply_ > cap_` reverts with {ERC20Capped-ERC20ExceededCap} during the mint.
     *      - `initialOwner_ == 0`    reverts with {Ownable-OwnableInvalidOwner}.
     *      The entire initial supply is minted to `initialOwner_`; distribution
     *      from there is an off-chain / operational concern.
     * @param name_          Human-readable token name (e.g. "Assessment Token").
     * @param symbol_        Ticker symbol (e.g. "AST").
     * @param cap_           Maximum total supply, in smallest units (wei). Must be > 0.
     * @param initialSupply_ Amount minted at deployment, in smallest units. Must be <= cap_.
     * @param initialOwner_  Address that receives the initial supply and owns the contract.
     */
    constructor(string memory name_, string memory symbol_, uint256 cap_, uint256 initialSupply_, address initialOwner_)
        ERC20(name_, symbol_)
        ERC20Capped(cap_)
        ERC20Permit(name_)
        Ownable(initialOwner_)
    {
        if (initialSupply_ != 0) {
            _mint(initialOwner_, initialSupply_);
        }
    }

    /**
     * @notice Mints `amount` new tokens to `to`, subject to the supply {cap}.
     * @dev Restricted to the owner. Reverts with {ZeroAmount} on a no-op mint,
     *      {ERC20InvalidReceiver} on the zero address (via OpenZeppelin), and
     *      {ERC20ExceededCap} if the mint would breach the cap.
     * @param to     Recipient of the newly minted tokens.
     * @param amount Amount to mint, in smallest units (wei).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
    }

    /**
     * @notice Returns the amount of tokens that can still be minted before hitting the {cap}.
     * @return The difference between {cap} and {totalSupply}, in smallest units.
     */
    function mintableRemaining() external view returns (uint256) {
        return cap() - totalSupply();
    }

    /**
     * @dev Resolves the diamond inheritance of `_update`, which is defined by
     *      {ERC20} and overridden by {ERC20Capped}. Solidity requires an explicit
     *      override to disambiguate the linearized call chain. The body simply
     *      forwards to `super`, so {ERC20Capped}'s cap enforcement runs on every
     *      mint, transfer, and burn.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
