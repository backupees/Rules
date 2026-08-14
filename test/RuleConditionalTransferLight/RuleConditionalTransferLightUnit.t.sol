// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

contract RuleConditionalTransferLightUnit is Test, HelperContract {
    RuleConditionalTransferLight private rule;

    function setUp() public {
        rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS3);
    }

    function testConstructorRevertsOnZeroAdmin() public {
        vm.expectRevert();
        new RuleConditionalTransferLight(address(0));
    }

    function testBindToken_RevertsIfAlreadyBound() public {
        vm.expectRevert(RuleConditionalTransferLight_TokenAlreadyBound.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
    }

    function testBindToken_RevertsForUnauthorizedCaller() public {
        RuleConditionalTransferLight freshRule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert();
        vm.prank(ADDRESS1);
        freshRule.bindToken(ADDRESS3);
    }

    function testApproveTransfer_OnlyOperator() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 1);
    }

    /**
     * @notice The approval count carried by {TransferApproved} must be the post-increment value.
     * @dev `approveTransfer` keeps the new count in a local rather than reading the slot back after
     *      storing it. The two are equivalent by construction, but nothing else in the suite asserts
     *      the event payload, so this pins it: a second approval of the same transfer must report 2,
     *      not 1 (pre-increment) and not 0 (uninitialised local).
     */
    function testApproveTransfer_EmitsPostIncrementCount() public {
        vm.expectEmit(true, true, false, true);
        emit TransferApproved(ADDRESS1, ADDRESS2, 10, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        vm.expectEmit(true, true, false, true);
        emit TransferApproved(ADDRESS1, ADDRESS2, 10, 2);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        // The event and the getter must agree.
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 2);
    }

    function testCancelTransferApproval_OnlyOperator() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.cancelTransferApproval(ADDRESS1, ADDRESS2, 10);
    }

    function testTransferred_OnlyBoundToken() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.transferred(ADDRESS1, ADDRESS2, 10);

        vm.prank(ADDRESS3);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    function testTransferred_RevertsWhenNotApproved() public {
        vm.expectRevert(TransferNotApproved.selector);
        vm.prank(ADDRESS3);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    function testDetectRestrictionAndCanTransferWhenApproved() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(resUint8, TRANSFER_OK);
        resBool = rule.canTransfer(ADDRESS1, ADDRESS2, 10);
        assertEq(resBool, true);
    }

    function testDetectRestrictionMintOrBurnPathReturnsTransferOk() public {
        resUint8 = rule.detectTransferRestriction(address(0), ADDRESS2, 10);
        assertEq(resUint8, TRANSFER_OK);

        resUint8 = rule.detectTransferRestriction(ADDRESS1, address(0), 10);
        assertEq(resUint8, TRANSFER_OK);

        resBool = rule.canTransfer(address(0), ADDRESS2, 10);
        assertTrue(resBool);

        resBool = rule.canTransfer(ADDRESS1, address(0), 10);
        assertTrue(resBool);
    }
}
