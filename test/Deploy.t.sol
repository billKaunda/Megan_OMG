// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, stdError} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {ImprovedAssessmentToken} from "../contracts/ImprovedAssessmentToken.sol";

/**
 * @title DeployTest
 * @author Bill Kaunda
 * @notice Coverage for the {Deploy} script — the deployment path itself.
 * @dev The script is the only part of the suite that runs against a real network with
 *      real funds, and several of its mistakes are unrecoverable once broadcast:
 *      {ERC20Capped-cap} is immutable, so a `TOKEN_CAP` wrong by a factor of 1e18 cannot
 *      be fixed after the fact. It earns the same scrutiny as the token.
 *
 *      ## Why these tests pass a config instead of setting env vars
 *
 *      Foundry's environment is process-global and its test runner is parallel, so
 *      `vm.setEnv` in one test races with every other test in the process.
 *
 *      Moving the baseline into `setUp` does not help: Foundry runs `setUp` once,
 *      snapshots EVM state, and reverts to that snapshot per test. `vm.setEnv` mutates
 *      state outside the EVM, so it is never rolled back. `forge test --threads 1` does
 *      fix it, but only when someone remembers the flag — and `threads = 1` in
 *      foundry.toml is accepted by `forge config` yet does not actually serialise the
 *      test runner, so a bare `forge test` stays flaky.
 *
 *      The fix was to make the script testable rather than to work around it: {Deploy}
 *      separates {Deploy-readConfig} (the only env reader) from {Deploy-validate} and
 *      {Deploy-deployToken}, which take an explicit {Deploy-TokenConfig}. These tests
 *      drive the latter two, so they touch no global state and are safe under any
 *      thread count.
 *
 *      The consequence is that {Deploy-readConfig} — env parsing and the `vm.envOr`
 *      defaults — is not asserted here; doing so would reintroduce exactly the race
 *      described above. It is covered end-to-end by `make deploy-local`, and its
 *      defaults are documented in `.env.example`.
 */
contract DeployTest is Test {
    Deploy internal deploy;

    string internal constant NAME = "Assessment Token";
    string internal constant SYMBOL = "AST";
    uint256 internal constant CAP_WHOLE = 1_000_000;
    uint256 internal constant INITIAL_WHOLE = 100_000;
    uint256 internal constant ONE_TOKEN = 1e18;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        deploy = new Deploy();
    }

    /// @dev The known-good config every test starts from, then mutates one field of.
    function _baseConfig() internal view returns (Deploy.TokenConfig memory) {
        return Deploy.TokenConfig({
            name: NAME,
            symbol: SYMBOL,
            capWhole: CAP_WHOLE,
            initialWhole: INITIAL_WHOLE,
            owner: owner
        });
    }

    /* ----------------------------------------------------------------------- */
    /*                             HAPPY PATH                                   */
    /* ----------------------------------------------------------------------- */

    function test_DeployToken_SetsConfiguredMetadata() public {
        ImprovedAssessmentToken token = deploy.deployToken(_baseConfig());

        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), 18);
    }

    /**
     * @dev The script's core responsibility. Config is in WHOLE tokens, the contract
     *      stores base units, and this is the single boundary where the 1e18 scaling
     *      happens. Getting it wrong is silent, and the cap is immutable afterwards.
     */
    function test_DeployToken_ScalesWholeTokensToBaseUnits() public {
        ImprovedAssessmentToken token = deploy.deployToken(_baseConfig());

        assertEq(token.cap(), CAP_WHOLE * ONE_TOKEN, "cap must be scaled to base units");
        assertEq(token.totalSupply(), INITIAL_WHOLE * ONE_TOKEN, "supply must be scaled");
        assertEq(token.mintableRemaining(), (CAP_WHOLE - INITIAL_WHOLE) * ONE_TOKEN);
    }

    function test_DeployToken_MintsEntireInitialSupplyToOwner() public {
        ImprovedAssessmentToken token = deploy.deployToken(_baseConfig());

        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(owner), INITIAL_WHOLE * ONE_TOKEN);
        assertEq(token.balanceOf(owner), token.totalSupply(), "no supply stranded elsewhere");
    }

    /// @dev Owner is decoupled from the deployer, so a multisig can own a key-deployed token.
    function test_DeployToken_OwnerIsIndependentOfDeployer() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.owner = alice;

        ImprovedAssessmentToken token = deploy.deployToken(cfg);

        assertEq(token.owner(), alice);
        assertEq(token.balanceOf(alice), INITIAL_WHOLE * ONE_TOKEN);
        assertEq(token.balanceOf(address(deploy)), 0, "deployer must not retain supply");
    }

    /// @dev cap == initialSupply is the fixed-supply configuration described in the review.
    function test_DeployToken_SupportsFixedSupplyConfiguration() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.initialWhole = cfg.capWhole;

        ImprovedAssessmentToken token = deploy.deployToken(cfg);

        assertEq(token.totalSupply(), token.cap());
        assertEq(token.mintableRemaining(), 0, "nothing left to mint");
    }

    function test_DeployToken_SupportsZeroInitialSupply() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.initialWhole = 0;

        ImprovedAssessmentToken token = deploy.deployToken(cfg);

        assertEq(token.totalSupply(), 0);
        assertEq(token.cap(), CAP_WHOLE * ONE_TOKEN);
    }

    /* ----------------------------------------------------------------------- */
    /*                        VALIDATION (FAIL FAST)                            */
    /* ----------------------------------------------------------------------- */

    function test_Validate_AcceptsBaseConfig() public view {
        deploy.validate(_baseConfig());
    }

    function test_RevertWhen_NameIsEmpty() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.name = "";

        vm.expectRevert(bytes("Deploy: TOKEN_NAME is empty"));
        deploy.validate(cfg);
    }

    function test_RevertWhen_SymbolIsEmpty() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.symbol = "";

        vm.expectRevert(bytes("Deploy: TOKEN_SYMBOL is empty"));
        deploy.validate(cfg);
    }

    function test_RevertWhen_CapIsZero() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.capWhole = 0;
        cfg.initialWhole = 0;

        vm.expectRevert(bytes("Deploy: TOKEN_CAP must be > 0"));
        deploy.validate(cfg);
    }

    function test_RevertWhen_InitialSupplyExceedsCap() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.initialWhole = cfg.capWhole + 1;

        vm.expectRevert(bytes("Deploy: initial supply exceeds cap"));
        deploy.validate(cfg);
    }

    function test_RevertWhen_OwnerIsZeroAddress() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.owner = address(0);

        vm.expectRevert(bytes("Deploy: TOKEN_OWNER is zero address"));
        deploy.validate(cfg);
    }

    /// @dev Validation must also guard the deploy path, not just be available to callers.
    function test_RevertWhen_DeployTokenGivenInvalidConfig() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.owner = address(0);

        vm.expectRevert(bytes("Deploy: TOKEN_OWNER is zero address"));
        deploy.deployToken(cfg);
    }

    /**
     * @dev The gap between the two units: validation runs on WHOLE tokens, so a cap that
     *      passes `capWhole != 0` can still overflow when scaled by 1e18. Checked
     *      arithmetic catches it, but as a bare panic rather than one of the script's
     *      actionable messages. Pinned so the behaviour is known here rather than
     *      discovered during a mainnet deploy.
     */
    function test_RevertWhen_CapOverflowsWhenScaledToBaseUnits() public {
        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.capWhole = type(uint256).max;
        cfg.initialWhole = 0;

        vm.expectRevert(stdError.arithmeticError);
        deploy.deployToken(cfg);
    }

    /* ----------------------------------------------------------------------- */
    /*                        POST-DEPLOY INVARIANTS                            */
    /* ----------------------------------------------------------------------- */

    function test_DeployToken_PostDeployStateMatchesIntent() public {
        ImprovedAssessmentToken token = deploy.deployToken(_baseConfig());

        assertEq(token.cap(), CAP_WHOLE * ONE_TOKEN, "cap invariant");
        assertEq(token.totalSupply(), INITIAL_WHOLE * ONE_TOKEN, "supply invariant");
        assertEq(token.owner(), owner, "owner invariant");
        assertEq(token.pendingOwner(), address(0), "no ownership transfer should be pending");
    }

    /// @dev A working token, not merely one whose constructor happened to return.
    function test_DeployToken_ProducesFunctionalToken() public {
        ImprovedAssessmentToken token = deploy.deployToken(_baseConfig());

        vm.prank(owner);
        token.transfer(alice, 1 ether);
        assertEq(token.balanceOf(alice), 1 ether);

        vm.prank(owner);
        token.mint(alice, 1 ether);
        assertEq(token.balanceOf(alice), 2 ether);
    }

    /* ----------------------------------------------------------------------- */
    /*                                 FUZZ                                     */
    /* ----------------------------------------------------------------------- */

    /**
     * @dev Scaling must hold across the plausible config space, not just the defaults.
     *      Bounded below `type(uint256).max / 1e18` to stay in the non-overflowing
     *      domain; the overflow edge has its own test above.
     */
    function testFuzz_DeployToken_ScalingHoldsForAnyValidConfig(uint256 capWhole, uint256 initialWhole) public {
        capWhole = bound(capWhole, 1, 1e27);
        initialWhole = bound(initialWhole, 0, capWhole);

        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.capWhole = capWhole;
        cfg.initialWhole = initialWhole;

        ImprovedAssessmentToken token = deploy.deployToken(cfg);

        assertEq(token.cap(), capWhole * ONE_TOKEN);
        assertEq(token.totalSupply(), initialWhole * ONE_TOKEN);
        assertLe(token.totalSupply(), token.cap(), "supply must never exceed cap");
    }

    /// @dev Any owner that isn't the zero address must receive the entire initial supply.
    function testFuzz_DeployToken_AnyValidOwnerReceivesSupply(address candidate) public {
        vm.assume(candidate != address(0));

        Deploy.TokenConfig memory cfg = _baseConfig();
        cfg.owner = candidate;

        ImprovedAssessmentToken token = deploy.deployToken(cfg);

        assertEq(token.owner(), candidate);
        assertEq(token.balanceOf(candidate), INITIAL_WHOLE * ONE_TOKEN);
    }
}
