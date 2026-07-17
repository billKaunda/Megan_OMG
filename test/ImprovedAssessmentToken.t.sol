// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ImprovedAssessmentToken} from "../contracts/ImprovedAssessmentToken.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ImprovedAssessmentTokenTest
 * @notice Behavioural, security, and fuzz coverage for {ImprovedAssessmentToken}.
 */
contract ImprovedAssessmentTokenTest is Test {
    ImprovedAssessmentToken internal token;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    string internal constant NAME = "Assessment Token";
    string internal constant SYMBOL = "AST";
    uint256 internal constant CAP = 1_000_000 ether;
    uint256 internal constant INITIAL = 100_000 ether;

    // Mirror of the events under test.
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new ImprovedAssessmentToken(NAME, SYMBOL, CAP, INITIAL, owner);
    }

    /* ----------------------------------------------------------------------- */
    /*                              DEPLOYMENT                                  */
    /* ----------------------------------------------------------------------- */

    function test_Metadata() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), 18);
    }

    function test_InitialSupplyMintedToOwner() public view {
        assertEq(token.totalSupply(), INITIAL);
        assertEq(token.balanceOf(owner), INITIAL);
        assertEq(token.cap(), CAP);
        assertEq(token.owner(), owner);
        assertEq(token.mintableRemaining(), CAP - INITIAL);
    }

    function test_ConstructorMintsTransferEventFromZero() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), owner, INITIAL);
        new ImprovedAssessmentToken(NAME, SYMBOL, CAP, INITIAL, owner);
    }

    function test_RevertWhen_CapIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20InvalidCap.selector, 0));
        new ImprovedAssessmentToken(NAME, SYMBOL, 0, 0, owner);
    }

    function test_RevertWhen_InitialSupplyExceedsCap() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        new ImprovedAssessmentToken(NAME, SYMBOL, CAP, CAP + 1, owner);
    }

    function test_RevertWhen_OwnerIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new ImprovedAssessmentToken(NAME, SYMBOL, CAP, INITIAL, address(0));
    }

    /* ----------------------------------------------------------------------- */
    /*                               TRANSFERS                                 */
    /* ----------------------------------------------------------------------- */

    function test_Transfer() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, alice, 1 ether);
        assertTrue(token.transfer(alice, 1 ether));

        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(token.balanceOf(owner), INITIAL - 1 ether);
    }

    function test_RevertWhen_TransferExceedsBalance() public {
        vm.prank(alice); // alice holds 0
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        token.transfer(bob, 1);
    }

    /// @dev The original contract silently burned tokens sent to address(0); OZ rejects it.
    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1 ether);
    }

    /* ----------------------------------------------------------------------- */
    /*                          APPROVE / TRANSFERFROM                         */
    /* ----------------------------------------------------------------------- */

    function test_ApproveAndTransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 10 ether);
        assertEq(token.allowance(owner, alice), 10 ether);

        vm.prank(alice);
        token.transferFrom(owner, bob, 4 ether);

        assertEq(token.balanceOf(bob), 4 ether);
        assertEq(token.allowance(owner, alice), 6 ether);
    }

    function test_RevertWhen_TransferFromExceedsAllowance() public {
        vm.prank(owner);
        token.approve(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 1 ether, 2 ether)
        );
        token.transferFrom(owner, bob, 2 ether);
    }

    /* ----------------------------------------------------------------------- */
    /*                                 MINT                                    */
    /* ----------------------------------------------------------------------- */

    function test_OwnerCanMintUpToCap() public {
        uint256 amount = CAP - INITIAL;
        vm.prank(owner);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), CAP);
        assertEq(token.mintableRemaining(), 0);
    }

    function test_RevertWhen_MintExceedsCap() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        token.mint(alice, CAP - INITIAL + 1);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, 1 ether);
    }

    function test_RevertWhen_MintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(ImprovedAssessmentToken.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    /* ----------------------------------------------------------------------- */
    /*                                 BURN                                    */
    /* ----------------------------------------------------------------------- */

    function test_Burn() public {
        vm.prank(owner);
        token.burn(10 ether);
        assertEq(token.totalSupply(), INITIAL - 10 ether);
        assertEq(token.balanceOf(owner), INITIAL - 10 ether);
    }

    function test_BurnFromWithAllowance() public {
        vm.prank(owner);
        token.approve(alice, 5 ether);

        vm.prank(alice);
        token.burnFrom(owner, 5 ether);

        assertEq(token.totalSupply(), INITIAL - 5 ether);
        assertEq(token.allowance(owner, alice), 0);
    }

    /// @dev Burning frees headroom under the cap, allowing it to be re-minted.
    function test_BurnThenRemintUnderCap() public {
        vm.startPrank(owner);
        token.mint(owner, CAP - INITIAL); // supply now at cap
        token.burn(1 ether);
        token.mint(owner, 1 ether); // fits again
        vm.stopPrank();
        assertEq(token.totalSupply(), CAP);
    }

    /* ----------------------------------------------------------------------- */
    /*                          OWNERSHIP (2-STEP)                             */
    /* ----------------------------------------------------------------------- */

    function test_TwoStepOwnershipTransfer() public {
        vm.prank(owner);
        token.transferOwnership(alice);
        // Ownership does not move until accepted.
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), alice);

        vm.prank(alice);
        token.acceptOwnership();
        assertEq(token.owner(), alice);
        assertEq(token.pendingOwner(), address(0));
    }

    function test_RevertWhen_WrongAccountAcceptsOwnership() public {
        vm.prank(owner);
        token.transferOwnership(alice);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        token.acceptOwnership();
    }

    /* ----------------------------------------------------------------------- */
    /*                          PERMIT (EIP-2612)                              */
    /* ----------------------------------------------------------------------- */

    function test_Permit() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        // Fund the signer so a later transferFrom is meaningful.
        vm.prank(owner);
        token.transfer(signer, 50 ether);

        uint256 value = 25 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        token.permit(signer, bob, value, deadline, v, r, s);

        assertEq(token.allowance(signer, bob), value);
        assertEq(token.nonces(signer), nonce + 1);
    }

    function test_RevertWhen_PermitExpired() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        uint256 deadline = block.timestamp - 1; // already expired
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                bob,
                1 ether,
                token.nonces(signer),
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        vm.expectRevert(abi.encodeWithSignature("ERC2612ExpiredSignature(uint256)", deadline));
        token.permit(signer, bob, 1 ether, deadline, v, r, s);
    }

    /* ----------------------------------------------------------------------- */
    /*                                 FUZZ                                    */
    /* ----------------------------------------------------------------------- */

    function testFuzz_TransferPreservesTotalSupply(uint256 amount) public {
        amount = bound(amount, 0, INITIAL);
        vm.prank(owner);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(owner) + token.balanceOf(alice), INITIAL);
        assertEq(token.totalSupply(), INITIAL);
    }

    function testFuzz_MintNeverExceedsCap(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max - INITIAL);
        vm.prank(owner);
        if (INITIAL + amount > CAP) {
            vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, INITIAL + amount, CAP));
            token.mint(alice, amount);
        } else {
            token.mint(alice, amount);
            assertLe(token.totalSupply(), CAP);
        }
    }
}
