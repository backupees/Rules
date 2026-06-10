// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {AccessControlModuleStandalone} from "src/modules/AccessControlModuleStandalone.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IERC3643ComplianceFull} from "src/mocks/IERC3643ComplianceFull.sol";

contract RuleMintAllowanceTest is Test, HelperContract {
    uint8 internal constant CODE_ALLOWANCE_EXCEEDED = 70;
    string internal constant TEXT_ALLOWANCE_EXCEEDED = "MintAllowance: minter allowance exceeded";

    address constant OPERATOR = address(10);
    address constant MINTER = address(11);
    address constant BOUND_ENGINE = address(12);

    RuleMintAllowance private rule;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        // Bind a fake engine so transferred() calls succeed
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(BOUND_ENGINE);
    }

    /*//////////////////////////////////////////////////////////////
                         DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function testCannotDeployWithZeroAdmin() public {
        vm.expectRevert(AccessControlModuleStandalone.AccessControlModuleStandalone_AddressZeroNotAllowed.selector);
        new RuleMintAllowance(ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                         ALLOWANCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function testSetMintAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        assertEq(rule.mintAllowance(MINTER), 1000);
    }

    function testSetMintAllowanceEmitsEvent() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectEmit(true, false, false, true);
        emit MintAllowanceSet(MINTER, 1000);
        rule.setMintAllowance(MINTER, 1000);
    }

    function testSetMintAllowanceOverridesExisting() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 500);
        assertEq(rule.mintAllowance(MINTER), 500);
    }

    function testIncreaseMintAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 500);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.increaseMintAllowance(MINTER, 300);
        assertEq(rule.mintAllowance(MINTER), 800);
    }

    function testIncreaseMintAllowanceEmitsEvent() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 500);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectEmit(true, false, false, true);
        emit MintAllowanceIncreased(MINTER, 300, 800);
        rule.increaseMintAllowance(MINTER, 300);
    }

    function testDecreaseMintAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.decreaseMintAllowance(MINTER, 400);
        assertEq(rule.mintAllowance(MINTER), 600);
    }

    function testDecreaseMintAllowanceEmitsEvent() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectEmit(true, false, false, true);
        emit MintAllowanceDecreased(MINTER, 400, 600);
        rule.decreaseMintAllowance(MINTER, 400);
    }

    function testDecreaseMintAllowanceRevertsOnUnderflow() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(RuleMintAllowance_DecreaseBelowZero.selector, MINTER, 100, 200));
        rule.decreaseMintAllowance(MINTER, 200);
    }

    function testDecreaseMintAllowanceToExactZero() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.decreaseMintAllowance(MINTER, 100);
        assertEq(rule.mintAllowance(MINTER), 0);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function testOnlyOperatorCanSetAllowance() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.setMintAllowance(MINTER, 1000);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(ALLOWANCE_OPERATOR_ROLE, OPERATOR);
        vm.prank(OPERATOR);
        rule.setMintAllowance(MINTER, 1000);
        assertEq(rule.mintAllowance(MINTER), 1000);
    }

    function testOnlyOperatorCanIncrease() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);

        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.increaseMintAllowance(MINTER, 50);
    }

    function testOnlyOperatorCanDecrease() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);

        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.decreaseMintAllowance(MINTER, 50);
    }

    function testDefaultAdminHasOperatorRole() public {
        assertTrue(rule.hasRole(ALLOWANCE_OPERATOR_ROLE, DEFAULT_ADMIN_ADDRESS));
    }

    /*//////////////////////////////////////////////////////////////
                   DETECT TRANSFER RESTRICTION
    //////////////////////////////////////////////////////////////*/

    function testDetectTransferRestrictionAlwaysOk() public view {
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 100), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 100), TRANSFER_OK);
    }

    function testCanTransferAlwaysTrue() public view {
        assertTrue(rule.canTransfer(ADDRESS1, ADDRESS2, 100));
        assertTrue(rule.canTransfer(ZERO_ADDRESS, ADDRESS2, 100));
    }

    function testDetectTransferRestrictionFromMintWithSufficientAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 500);
        assertEq(rule.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 500), TRANSFER_OK);
        assertTrue(rule.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 500));
    }

    function testDetectTransferRestrictionFromMintExceedsAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);
        assertEq(rule.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 101), CODE_ALLOWANCE_EXCEEDED);
        assertFalse(rule.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 101));
    }

    function testDetectTransferRestrictionFromRegularTransferAlwaysOk() public view {
        // Non-mint transfers are always OK regardless of allowance
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10000), TRANSFER_OK);
        assertTrue(rule.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10000));
    }

    function testDetectTransferRestrictionFromBurnAlwaysOk() public view {
        // Burns (to == address(0)) are not restricted
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS1, ADDRESS1, ZERO_ADDRESS, 10000), TRANSFER_OK);
        assertTrue(rule.canTransferFrom(ADDRESS1, ADDRESS1, ZERO_ADDRESS, 10000));
    }

    function testZeroAllowanceMintBlocked() public view {
        // Default allowance is 0; any mint amount should be blocked
        assertEq(rule.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 1), CODE_ALLOWANCE_EXCEEDED);
        assertFalse(rule.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 1));
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFERRED (STATE)
    //////////////////////////////////////////////////////////////*/

    function testTransferredFourArgConsumesAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(BOUND_ENGINE);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 400);
        assertEq(rule.mintAllowance(MINTER), 600);
    }

    function testTransferredFourArgEmitsConsumedEvent() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(BOUND_ENGINE);
        vm.expectEmit(true, false, false, true);
        emit MintAllowanceConsumed(MINTER, 400, 600);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 400);
    }

    function testTransferredFourArgRevertsOnExceedAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);
        vm.prank(BOUND_ENGINE);
        vm.expectRevert(
            abi.encodeWithSelector(RuleMintAllowance_AllowanceExceeded.selector, address(rule), MINTER, 100, 101)
        );
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 101);
    }

    function testTransferredFourArgRegularTransferNoOp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        // Regular transfer (from != address(0)) should not affect allowance
        vm.prank(BOUND_ENGINE);
        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 500);
        assertEq(rule.mintAllowance(MINTER), 1000);
    }

    function testTransferredThreeArgNoOp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        // 3-arg path: no deduction even for from == address(0)
        vm.prank(BOUND_ENGINE);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 500);
        assertEq(rule.mintAllowance(MINTER), 1000);
    }

    function testTransferredOnlyBoundTokenCan3Arg() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    function testTransferredOnlyBoundTokenCan4Arg() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 100);
    }

    function testMultipleMintConsumesSequentially() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);

        vm.prank(BOUND_ENGINE);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 300);
        assertEq(rule.mintAllowance(MINTER), 700);

        vm.prank(BOUND_ENGINE);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS2, 700);
        assertEq(rule.mintAllowance(MINTER), 0);

        // Next mint must fail
        vm.prank(BOUND_ENGINE);
        vm.expectRevert();
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testSetAllowanceResetsAfterExhaustion() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 100);
        vm.prank(BOUND_ENGINE);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 100);
        assertEq(rule.mintAllowance(MINTER), 0);

        // Operator resets the allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 200);
        assertEq(rule.mintAllowance(MINTER), 200);

        vm.prank(BOUND_ENGINE);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 200);
        assertEq(rule.mintAllowance(MINTER), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    RESTRICTION CODE & MESSAGE
    //////////////////////////////////////////////////////////////*/

    function testCanReturnRestrictionCode() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_ALLOWANCE_EXCEEDED));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    function testMessageForTransferRestriction() public view {
        assertEq(rule.messageForTransferRestriction(CODE_ALLOWANCE_EXCEEDED), TEXT_ALLOWANCE_EXCEEDED);
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC-165
    //////////////////////////////////////////////////////////////*/

    function testSupportsInterface() public view {
        assertTrue(rule.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(rule.supportsInterface(RuleInterfaceId.IRULE_INTERFACE_ID));
        assertTrue(rule.supportsInterface(ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID));
        assertTrue(rule.supportsInterface(RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID));
        assertTrue(rule.supportsInterface(type(IERC7551Compliance).interfaceId));
        assertFalse(rule.supportsInterface(type(IERC3643ComplianceFull).interfaceId));
        assertFalse(rule.supportsInterface(bytes4(0xdeadbeef)));
    }

    /*//////////////////////////////////////////////////////////////
                    COMPLIANCE MODULE (BINDING)
    //////////////////////////////////////////////////////////////*/

    function testBindTokenOnlyComplianceManager() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.bindToken(ADDRESS2);

        vm.expectRevert(RuleMintAllowance_TokenAlreadyBound.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS2);
    }

    function testBindTokenAfterUnbind() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(BOUND_ENGINE);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS2);
        assertTrue(rule.isTokenBound(ADDRESS2));
    }

    function testUnbindToken() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(BOUND_ENGINE);
        assertFalse(rule.isTokenBound(BOUND_ENGINE));
    }

    function testCreatedAndDestroyedAreNoOps() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(BOUND_ENGINE);
        rule.created(ADDRESS1, 500);
        assertEq(rule.mintAllowance(MINTER), 1000);

        vm.prank(BOUND_ENGINE);
        rule.destroyed(ADDRESS1, 300);
        assertEq(rule.mintAllowance(MINTER), 1000);
    }
}
