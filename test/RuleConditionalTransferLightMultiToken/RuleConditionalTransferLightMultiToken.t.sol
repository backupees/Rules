// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {MockERC20WithTransferContext} from "src/mocks/MockERC20WithTransferContext.sol";

contract RuleConditionalTransferLightMultiTokenTest is Test, HelperContract {
    RuleConditionalTransferLightMultiToken private rule;
    MockERC20WithTransferContext private tokenA;
    MockERC20WithTransferContext private tokenB;

    function setUp() public {
        tokenA = new MockERC20WithTransferContext("Token A", "TKNA");
        tokenB = new MockERC20WithTransferContext("Token B", "TKNB");

        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(tokenA));
        rule.bindToken(address(tokenB));
        vm.stopPrank();

        tokenA.setRule(address(rule));
        tokenB.setRule(address(rule));

        tokenA.mint(ADDRESS1, 100);
        tokenB.mint(ADDRESS1, 100);
    }

    function testApprovalForTokenADoesNotAuthorizeTokenB() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(tokenA), ADDRESS1, ADDRESS2, 10);

        vm.prank(ADDRESS1);
        tokenA.transfer(ADDRESS2, 10);

        assertEq(tokenA.balanceOf(ADDRESS1), 90);
        assertEq(tokenA.balanceOf(ADDRESS2), 10);

        vm.expectRevert();
        vm.prank(ADDRESS1);
        tokenB.transfer(ADDRESS2, 10);
    }

    function testApproveAndTransferIfAllowedUsesTokenScopedApproval() public {
        vm.prank(ADDRESS1);
        tokenA.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(address(tokenA), ADDRESS1, ADDRESS2, 10);

        assertEq(tokenA.balanceOf(ADDRESS1), 90);
        assertEq(tokenA.balanceOf(ADDRESS2), 10);
        assertEq(rule.approvedCount(address(tokenA), ADDRESS1, ADDRESS2, 10), 0);
        assertEq(rule.approvedCount(address(tokenB), ADDRESS1, ADDRESS2, 10), 0);
    }

    function testApproveTransferRevertsForUnboundToken() public {
        vm.expectRevert();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }
}
