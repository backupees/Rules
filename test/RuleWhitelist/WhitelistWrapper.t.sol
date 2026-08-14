// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {AccessControlModuleStandalone} from "../../src/modules/AccessControlModuleStandalone.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleWhitelistWrapperHarnessInternal} from "src/mocks/harness/RuleWhitelistWrapperHarnessInternal.sol";
/**
 * @title Integration test with the CMTAT
 */

contract CMTATIntegrationWhitelistWrapper is Test, HelperContract {
    uint256 constant ADDRESS1_BALANCE_INIT = 31;
    uint256 constant ADDRESS2_BALANCE_INIT = 32;
    uint256 constant ADDRESS3_BALANCE_INIT = 33;

    uint256 constant FLAG = 5;
    RuleWhitelist ruleWhitelist2;
    RuleWhitelist ruleWhitelist3;
    RuleWhitelistWrapper ruleWhitelistWrapper;

    // Arrange
    function setUp() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);
        ruleWhitelist2 = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);
        ruleWhitelist3 = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);
        ruleWhitelistWrapper = new RuleWhitelistWrapper(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, true);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist2);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist3);
    }

    /**
     * Deployment ******
     */
    function testCannotDeployContractIfAdminAddressIsZero() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        vm.expectRevert(AccessControlModuleStandalone.AccessControlModuleStandalone_AddressZeroNotAllowed.selector);
        ruleWhitelistWrapper = new RuleWhitelistWrapper(ZERO_ADDRESS, ZERO_ADDRESS, true, true);
    }

    function testReturnTheRightMessageForAGivenCode() public {
        // Assert
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
        // Act
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_TO_NOT_WHITELISTED);

        // Act
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_NONEXISTENT);
        // Assert
        assertEq(resString, TEXT_CODE_NOT_FOUND);
    }

    function testWrapperWithZeroRulesRejectsTransfers() public {
        RuleWhitelistWrapper emptyWrapper =
            new RuleWhitelistWrapper(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, true);

        resUint8 = emptyWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        resBool = emptyWrapper.canTransfer(ADDRESS1, ADDRESS2, 20);
        assertEq(resBool, false);
    }

    function testDetectTransferRestrictionFrom() public {
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelistWrapper.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, false);

        // Act
        resBool = ruleWhitelistWrapper.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, false);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelistWrapper),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_FROM_NOT_WHITELISTED
            )
        );
        // Act
        ruleWhitelistWrapper.transferred(ADDRESS1, ADDRESS2, 20);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelistWrapper),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_FROM_NOT_WHITELISTED
            )
        );
        ruleWhitelistWrapper.transferred(ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionTo() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelistWrapper),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_TO_NOT_WHITELISTED
            )
        );
        // Act
        ruleWhitelistWrapper.transferred(ADDRESS1, ADDRESS2, 20);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelistWrapper),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_TO_NOT_WHITELISTED
            )
        );
        ruleWhitelistWrapper.transferred(ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionWithSpender() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, false);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, false);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransferFrom.selector,
                address(ruleWhitelistWrapper),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_SPENDER_NOT_WHITELISTED
            )
        );
        // Act
        ruleWhitelistWrapper.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 20);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransferFrom.selector,
                address(ruleWhitelistWrapper),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_SPENDER_NOT_WHITELISTED
            )
        );
        ruleWhitelistWrapper.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionWithSpenderFromNotWhitelisted() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);

        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);
    }

    function testDetectTransferRestrictionWithSpenderToNotWhitelisted() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);

        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);
    }

    function testDetectTransferRestrictionFromIgnoresSpenderWhenCheckDisabled() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.setCheckSpender(false);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);

        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, NO_ERROR);
    }

    function testDetectTransferRestrictionOk() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // No revert
        // Act
        ruleWhitelistWrapper.transferred(ADDRESS1, ADDRESS2, 20);
        ruleWhitelistWrapper.transferred(ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionWithSpenderOk() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, true);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, true);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // No revert
        // Act
        ruleWhitelistWrapper.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        ruleWhitelistWrapper.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
    }

    /*//////////////////////////////////////////////////////////////
                          IS VERIFIED
    //////////////////////////////////////////////////////////////*/

    function testIsVerifiedListedInOneChildRule() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        // Listed in ruleWhitelist → verified via wrapper
        assertTrue(ruleWhitelistWrapper.isVerified(ADDRESS1));
    }

    function testIsVerifiedListedInSecondChildRule() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist2.addAddress(ADDRESS1);

        assertTrue(ruleWhitelistWrapper.isVerified(ADDRESS1));
    }

    function testIsVerifiedNotListedInAnyRule() public view {
        assertFalse(ruleWhitelistWrapper.isVerified(ADDRESS1));
    }

    /**
     * @notice A target listed in several child rules must be counted as resolved exactly once.
     * @dev ADDRESS1 sits in two children while ADDRESS2 sits only in the third, so the scan
     *      necessarily re-encounters ADDRESS1 as already resolved before reaching child 3. This
     *      pins the `!result[j]` guard in `_detectTransferRestrictionForTargets`: without it the
     *      second listing of ADDRESS1 would decrement the resolved counter a second time, driving
     *      it to zero and breaking out of the scan before child 3 is ever consulted -- ADDRESS2
     *      would then be reported unlisted and a valid transfer rejected.
     */
    function testDetectTransferRestrictionOkWhenAddressListedInSeveralChildRules() public {
        // Arrange: ADDRESS1 in child 1 AND child 2, ADDRESS2 only in child 3.
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist2.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist3.addAddress(ADDRESS2);

        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // The same holds for the spender overload, which resolves three targets instead of two.
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist2.addAddress(ADDRESS3);
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, NO_ERROR);
    }

    function testIsVerifiedWithNoChildRules() public {
        RuleWhitelistWrapper emptyWrapper =
            new RuleWhitelistWrapper(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, true);
        assertFalse(emptyWrapper.isVerified(ADDRESS1));
    }

    function testInternalTransferredSpenderOverload() public {
        RuleWhitelistWrapperHarnessInternal wrapperHarness =
            new RuleWhitelistWrapperHarnessInternal(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, true);
        RuleWhitelist child = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        wrapperHarness.addRule(child);

        vm.startPrank(WHITELIST_OPERATOR_ADDRESS);
        child.addAddress(ADDRESS1);
        child.addAddress(ADDRESS2);
        child.addAddress(ADDRESS3);
        vm.stopPrank();

        wrapperHarness.exposedTransferredSpenderInternal(ADDRESS3, ADDRESS1, ADDRESS2, 20);
    }
}
