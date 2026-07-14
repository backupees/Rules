// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";

/**
 * @title MultiTokenPreflightView
 * @notice Covers the caller-explicit pre-flight views added by improvement I-7 (threat `CTL-4`,
 *         finding F-8).
 * @dev `detectTransferRestriction` / `canTransfer` derive the token key from `msg.sender`, so any
 *      caller that is not the bound token reads "not approved" even for an approved transfer.
 *      `detectTransferRestrictionForToken` / `canTransferForToken` take the token explicitly and
 *      therefore give every caller the real answer.
 */
contract MultiTokenPreflightView is Test, HelperContract {
    RuleConditionalTransferLightMultiToken private rule;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        vm.stopPrank();
    }

    /**
     * @notice The explicit view returns the true answer regardless of who asks — including an
     *         arbitrary off-chain caller, which is exactly the case the ERC-1404 view cannot serve.
     */
    function test_ExplicitViewIsCallerIndependent() public {
        // The bound token gets the right answer from both views.
        vm.prank(ADDRESS1);
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS3, 10), TRANSFER_OK);
        assertEq(rule.detectTransferRestrictionForToken(ADDRESS1, ADDRESS2, ADDRESS3, 10), TRANSFER_OK);

        // An unrelated caller gets a MISLEADING answer from the ERC-1404 view...
        vm.prank(ATTACKER);
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS3, 10), CODE_TRANSFER_REQUEST_NOT_APPROVED);

        // ...but the correct one from the explicit view.
        vm.prank(ATTACKER);
        assertEq(rule.detectTransferRestrictionForToken(ADDRESS1, ADDRESS2, ADDRESS3, 10), TRANSFER_OK);
    }

    /**
     * @notice `canTransferForToken` is the boolean counterpart and is likewise caller-independent.
     */
    function test_CanTransferForTokenIsCallerIndependent() public {
        vm.prank(ATTACKER);
        assertEq(rule.canTransfer(ADDRESS2, ADDRESS3, 10), false, "caller-dependent view misleads");

        vm.prank(ATTACKER);
        assertEq(rule.canTransferForToken(ADDRESS1, ADDRESS2, ADDRESS3, 10), true, "explicit view is truthful");
    }

    /**
     * @notice The explicit view reports an unapproved transfer as restricted.
     */
    function test_ExplicitViewReportsUnapprovedTransfer() public view {
        assertEq(
            rule.detectTransferRestrictionForToken(ADDRESS1, ADDRESS2, ADDRESS3, 999),
            CODE_TRANSFER_REQUEST_NOT_APPROVED
        );
        assertEq(rule.canTransferForToken(ADDRESS1, ADDRESS2, ADDRESS3, 999), false);
    }

    /**
     * @notice Approvals stay token-scoped in the explicit view: an unbound token is fail-closed.
     */
    function test_ExplicitViewIsTokenScopedAndFailsClosedForUnboundToken() public view {
        // ADDRESS2 was never bound, so it has no consumable approvals.
        assertEq(
            rule.detectTransferRestrictionForToken(ADDRESS2, ADDRESS2, ADDRESS3, 10), CODE_TRANSFER_REQUEST_NOT_APPROVED
        );
        assertEq(rule.canTransferForToken(ADDRESS2, ADDRESS2, ADDRESS3, 10), false);
    }

    /**
     * @notice Mint and burn are exempt on the explicit view too, matching the enforcement path.
     */
    function test_ExplicitViewExemptsMintAndBurn() public view {
        assertEq(rule.detectTransferRestrictionForToken(ADDRESS1, ZERO_ADDRESS, ADDRESS3, 10), TRANSFER_OK);
        assertEq(rule.detectTransferRestrictionForToken(ADDRESS1, ADDRESS2, ZERO_ADDRESS, 10), TRANSFER_OK);
    }

    /**
     * @notice The explicit view tracks consumption: once the approval is spent it reports restricted.
     */
    function test_ExplicitViewTracksConsumption() public {
        assertEq(rule.canTransferForToken(ADDRESS1, ADDRESS2, ADDRESS3, 10), true);

        vm.prank(ADDRESS1);
        rule.transferred(ADDRESS2, ADDRESS3, 10);

        assertEq(rule.canTransferForToken(ADDRESS1, ADDRESS2, ADDRESS3, 10), false);
        assertEq(
            rule.detectTransferRestrictionForToken(ADDRESS1, ADDRESS2, ADDRESS3, 10), CODE_TRANSFER_REQUEST_NOT_APPROVED
        );
    }

    /**
     * @notice The two views can never disagree: both are backed by the same internal helper, so for
     *         the bound token the ERC-1404 view and the explicit view always agree.
     */
    function testFuzz_ViewsAgreeForTheBoundToken(address from, address to, uint256 value) public {
        vm.assume(from != ZERO_ADDRESS && to != ZERO_ADDRESS);

        vm.prank(ADDRESS1);
        uint8 implicitCode = rule.detectTransferRestriction(from, to, value);
        uint8 explicitCode = rule.detectTransferRestrictionForToken(ADDRESS1, from, to, value);

        assertEq(implicitCode, explicitCode, "implicit and explicit views disagree");
    }
}
