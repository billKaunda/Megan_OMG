// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ImprovedAssessmentToken} from "../contracts/ImprovedAssessmentToken.sol";

/**
 * @title Deploy
 * @notice Production-grade deployment script for {ImprovedAssessmentToken}.
 * @dev Configuration is read entirely from environment variables so the same
 *      script deploys deterministically across local / testnet / mainnet without
 *      code changes. Human-friendly "whole token" amounts are scaled to the
 *      token's 18 decimals here, at the tooling boundary, keeping the contract
 *      itself free of implicit multiplication.
 *
 *      Required env:
 *        PRIVATE_KEY            uint  — deployer key (broadcaster).
 *      Optional env (with sane defaults):
 *        TOKEN_NAME             string
 *        TOKEN_SYMBOL           string
 *        TOKEN_CAP              uint  — max supply in WHOLE tokens.
 *        TOKEN_INITIAL_SUPPLY   uint  — initial mint in WHOLE tokens.
 *        TOKEN_OWNER            address — owner / initial holder; defaults to the deployer.
 *
 *      Usage:
 *        forge script script/Deploy.s.sol:Deploy \
 *          --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
 */
contract Deploy is Script {
    uint256 private constant ONE_TOKEN = 1e18;

    /**
     * @notice Deployment parameters, denominated in WHOLE tokens.
     * @dev Scaling to base units happens once, in {deployToken}. Keeping the config in
     *      whole tokens up to that point means there is exactly one multiplication in
     *      the whole pipeline to get wrong.
     */
    struct TokenConfig {
        string name;
        string symbol;
        uint256 capWhole;
        uint256 initialWhole;
        address owner;
    }

    /**
     * @notice Entry point: read config from the environment and deploy.
     * @dev Structured so that reading the environment ({readConfig}) is separate from
     *      validating ({validate}) and deploying ({deployToken}). Only this function
     *      touches env or broadcasts, which lets the tests exercise the real validation
     *      and deployment logic by passing a {TokenConfig} directly — no `vm.setEnv`,
     *      and therefore no dependence on process-global state that Foundry's parallel
     *      test runner would race on.
     */
    function run() external returns (ImprovedAssessmentToken token) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        TokenConfig memory cfg = readConfig(deployer);

        // Fail fast with actionable messages. `forge script` simulates before it sends,
        // so an invalid config aborts here without broadcasting or spending gas.
        validate(cfg);

        vm.startBroadcast(deployerKey);
        token = deployToken(cfg);
        vm.stopBroadcast();

        _report(cfg, token, deployer);
    }

    /**
     * @notice Read deployment config from environment variables.
     * @dev Every value except the deployer key has a sane default, so a bare
     *      `make deploy-local` works with only `PRIVATE_KEY` set. Amounts are WHOLE
     *      tokens; see {TokenConfig}.
     * @param deployer Fallback owner when `TOKEN_OWNER` is not set.
     */
    function readConfig(address deployer) public view returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            name: vm.envOr("TOKEN_NAME", string("Assessment Token")),
            symbol: vm.envOr("TOKEN_SYMBOL", string("AST")),
            capWhole: vm.envOr("TOKEN_CAP", uint256(1_000_000)),
            initialWhole: vm.envOr("TOKEN_INITIAL_SUPPLY", uint256(100_000)),
            owner: vm.envOr("TOKEN_OWNER", deployer)
        });
    }

    /**
     * @notice Reject a config that would deploy a broken or unusable token.
     * @dev `pure` and free of env/broadcast, so it is directly unit-testable. The token's
     *      own constructor re-checks the cap and owner via OpenZeppelin; these checks
     *      exist to fail earlier and with a message that names the offending env var.
     */
    function validate(TokenConfig memory cfg) public pure {
        require(bytes(cfg.name).length != 0, "Deploy: TOKEN_NAME is empty");
        require(bytes(cfg.symbol).length != 0, "Deploy: TOKEN_SYMBOL is empty");
        require(cfg.capWhole != 0, "Deploy: TOKEN_CAP must be > 0");
        require(cfg.initialWhole <= cfg.capWhole, "Deploy: initial supply exceeds cap");
        require(cfg.owner != address(0), "Deploy: TOKEN_OWNER is zero address");
    }

    /**
     * @notice Deploy the token from an explicit config, scaling whole tokens to base units.
     * @dev Validates first, then asserts the deployed state matches intent — so a
     *      misconfigured or partially-applied deploy fails loudly rather than leaving a
     *      wrong-but-live token on-chain.
     */
    function deployToken(TokenConfig memory cfg) public returns (ImprovedAssessmentToken token) {
        validate(cfg);

        uint256 cap = cfg.capWhole * ONE_TOKEN;
        uint256 initialSupply = cfg.initialWhole * ONE_TOKEN;

        token = new ImprovedAssessmentToken(cfg.name, cfg.symbol, cap, initialSupply, cfg.owner);

        require(token.cap() == cap, "Deploy: cap mismatch");
        require(token.totalSupply() == initialSupply, "Deploy: supply mismatch");
        require(token.owner() == cfg.owner, "Deploy: owner mismatch");
    }

    /// @dev Human-readable deployment summary.
    function _report(TokenConfig memory cfg, ImprovedAssessmentToken token, address deployer) private view {
        console2.log("=== ImprovedAssessmentToken deployed ===");
        console2.log("chain id       :", block.chainid);
        console2.log("address        :", address(token));
        console2.log("deployer       :", deployer);
        console2.log("owner / holder :", cfg.owner);
        console2.log("name / symbol  :", cfg.name, cfg.symbol);
        console2.log("cap (whole)    :", cfg.capWhole);
        console2.log("initial (whole):", cfg.initialWhole);
    }
}
