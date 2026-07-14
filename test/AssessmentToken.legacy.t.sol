// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AssessmentToken} from "../contracts/AssessmentToken.sol";

/**
 * @title AssessmentTokenLegacyTest
 * @author Bill Kaunda
 * @notice Characterisation tests for the ORIGINAL {AssessmentToken}.
 * @dev These tests deliberately assert the original contract's behaviour *as it
 *      actually is*, including its defects. They are not a claim that this
 *      behaviour is correct — they are executable documentation of why
 *      {ImprovedAssessmentToken} exists, and they keep the review in
 *      `SMART_CONTRACT_REVIEW.md` honest: every flaw described there is proven
 *      here rather than asserted.
 *
 *      Each `test_Legacy_*` case is paired with the test in
 *      `ImprovedAssessmentToken.t.sol` that demonstrates the fix.
 */
contract AssessmentTokenLegacyTest is Test {
    AssessmentToken internal token;

    address internal deployer = address(this);
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL_WHOLE = 1_000;
    uint256 internal constant INITIAL = INITIAL_WHOLE * 1e18;

    function setUp() public {
        token = new AssessmentToken(INITIAL_WHOLE);
    }

    /* ----------------------------------------------------------------------- */
    /*                          BASELINE (WORKS AS INTENDED)                    */
    /* ----------------------------------------------------------------------- */

    /// @dev The constructor scales by `10**decimals` internally, so callers pass WHOLE tokens.
    function test_Legacy_ConstructorScalesWholeTokens() public view {
        assertEq(token.totalSupply(), INITIAL);
        assertEq(token.balanceOf(deployer), INITIAL);
        assertEq(token.decimals(), 18);
    }

    /// @dev Self-transfer is safe: the -= and += are sequential storage writes.
    function test_Legacy_SelfTransferDoesNotCorruptBalance() public {
        uint256 before = token.balanceOf(deployer);
        token.transfer(deployer, 50 ether);
        assertEq(token.balanceOf(deployer), before);
    }

    /* ----------------------------------------------------------------------- */
    /*                       DEFECT 1: ZERO-ADDRESS BURN                        */
    /* ----------------------------------------------------------------------- */

    /**
     * @dev The original `transfer` never checks `to != address(0)`. Tokens sent
     *      there are unrecoverable, yet `totalSupply` is NOT decremented — so
     *      `totalSupply` permanently overstates the circulating supply, and the
     *      ERC-20 invariant `sum(balances) == totalSupply` only holds if you
     *      count an address nobody can spend from.
     *
     *      Fixed in {ImprovedAssessmentToken}: OpenZeppelin's `_update` reverts
     *      with `ERC20InvalidReceiver`. See
     *      `ImprovedAssessmentTokenTest.test_RevertWhen_TransferToZeroAddress`.
     *      Intentional supply reduction is instead exposed via {ERC20Burnable},
     *      which correctly lowers `totalSupply`.
     */
    function test_Legacy_TransferToZeroAddressStrandsTokensWithoutBurning() public {
        uint256 supplyBefore = token.totalSupply();

        token.transfer(address(0), 100 ether);

        assertEq(token.totalSupply(), supplyBefore, "totalSupply was not reduced");
        assertEq(token.balanceOf(address(0)), 100 ether, "tokens stranded at address(0)");
        assertEq(token.balanceOf(deployer), supplyBefore - 100 ether);
    }

    /// @dev `transferFrom` has the same missing check.
    function test_Legacy_TransferFromToZeroAddressAlsoAllowed() public {
        token.approve(alice, 10 ether);

        vm.prank(alice);
        assertTrue(token.transferFrom(deployer, address(0), 10 ether));
        assertEq(token.balanceOf(address(0)), 10 ether);
    }

    /* ----------------------------------------------------------------------- */
    /*                    DEFECT 2: UNVALIDATED APPROVE TARGET                  */
    /* ----------------------------------------------------------------------- */

    /**
     * @dev `approve` validates neither the spender nor the caller. Approving
     *      `address(0)` is a silent no-op that still emits {Approval}, so an
     *      integrator watching events sees an allowance that can never be used.
     *      OpenZeppelin rejects this with `ERC20InvalidSpender`.
     */
    function test_Legacy_ApproveZeroAddressSpenderSucceeds() public {
        assertTrue(token.approve(address(0), 5 ether));
        assertEq(token.allowance(deployer, address(0)), 5 ether);
    }

    /* ----------------------------------------------------------------------- */
    /*                   DEFECT 3: ERC-20 APPROVE RACE CONDITION                */
    /* ----------------------------------------------------------------------- */

    /**
     * @dev The classic ERC-20 approve front-running hazard. `approve` overwrites
     *      the allowance outright rather than adjusting it. A spender who sees a
     *      pending re-approval can spend the OLD allowance first, then spend the
     *      NEW one — extracting `old + new` instead of `new`.
     *
     *      This is inherent to the ERC-20 standard and OpenZeppelin does not
     *      "fix" it either. {ImprovedAssessmentToken} mitigates it by shipping
     *      {ERC20Permit}, which lets an owner issue an exact, nonce-bound,
     *      time-bound allowance — each signature is single-use, so a replay of
     *      the stale approval is not possible.
     */
    function test_Legacy_ApproveRaceAllowsSpendingOldAndNewAllowance() public {
        token.approve(alice, 100 ether);

        // Alice front-runs the owner's re-approval and drains the old allowance.
        vm.prank(alice);
        token.transferFrom(deployer, bob, 100 ether);

        // The owner's re-approval lands afterwards.
        token.approve(alice, 20 ether);

        vm.prank(alice);
        token.transferFrom(deployer, bob, 20 ether);

        // Alice moved 120 despite the owner only ever intending 100 then 20.
        assertEq(token.balanceOf(bob), 120 ether);
    }

    /* ----------------------------------------------------------------------- */
    /*                  DEFECT 4: NO ACCESS CONTROL / NO SUPPLY LEVERS          */
    /* ----------------------------------------------------------------------- */

    /**
     * @dev The original exposes no mint, no burn, and no owner. Supply is fixed
     *      forever at construction. That is a defensible design, but it is an
     *      implicit one — there is no cap to reason about because there is no
     *      minting, and no way to retire supply because there is no burn.
     *      {ImprovedAssessmentToken} makes the choice explicit: owner-gated
     *      minting bounded by an immutable {ERC20Capped-cap}, plus real burning.
     */
    function test_Legacy_SupplyIsImmutableWithNoMintOrBurnPath() public view {
        // Nothing to call: the ABI has no mint/burn/owner. Supply is whatever
        // the constructor set, and the only way to reduce it is the buggy
        // zero-address path proven above.
        assertEq(token.totalSupply(), INITIAL);
    }

    /* ----------------------------------------------------------------------- */
    /*                                  FUZZ                                    */
    /* ----------------------------------------------------------------------- */

    /// @dev Arithmetic itself is sound — Solidity >=0.8 checked math reverts on underflow.
    function testFuzz_Legacy_TransferRevertsOnInsufficientBalance(uint256 amount) public {
        amount = bound(amount, INITIAL + 1, type(uint256).max);
        vm.expectRevert(bytes("insufficient balance"));
        token.transfer(alice, amount);
    }
}
