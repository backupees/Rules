// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";

/**
 * @title StaleStateHygiene
 * @notice Covers the state-clearing functions added by improvement I-6 (threat `BIND-1`, finding F-9).
 * @dev `unbindToken` does not clear `approvalCounts` / `mintAllowance`. These tests verify the new
 *      `resetApproval` / `clearMintAllowances` operations let an operator discard that state before
 *      rebinding, and that they are correctly access-controlled.
 */
contract StaleStateHygiene is Test, HelperContract {
    /**
     * @dev Redeclared locally: `HelperContract` already inherits the single-token invariant storage,
     *      whose constants clash with the multi-token variant's.
     */
    error RuleConditionalTransferLightMultiToken_TransferApprovalNotFound();
    error RuleConditionalTransferLightMultiToken_InvalidToken();

    address private constant MINTER = address(10);

    /*//////////////////////////////////////////////////////////////
                RuleConditionalTransferLight.resetApproval
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice BIND-1: an operator can discard stale approvals before rebinding, so they are NOT
     *         consumable by the newly bound token.
     */
    function test_ResetApprovalPreventsStaleApprovalSurvivingRebind() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.unbindToken(ADDRESS1);

        // Cleanup must work while NOTHING is bound — that is the whole point.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        uint256 cleared = ruleConditionalTransferLight.resetApproval(ADDRESS2, ADDRESS3, 10);
        assertEq(cleared, 1);
        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 0);

        // The new token cannot consume the discarded approval.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindToken(ATTACKER);
        vm.prank(ATTACKER);
        vm.expectRevert(TransferNotApproved.selector);
        ruleConditionalTransferLight.transferred(ADDRESS2, ADDRESS3, 10);
    }

    /**
     * @notice `resetApproval` discards ALL outstanding approvals for the tuple in one call,
     *         unlike `cancelTransferApproval` which removes exactly one.
     */
    function test_ResetApprovalClearsEveryOutstandingApproval() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);
        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 3);

        vm.expectEmit(true, true, false, true);
        emit TransferApprovalReset(ADDRESS2, ADDRESS3, 10, 3);
        uint256 cleared = ruleConditionalTransferLight.resetApproval(ADDRESS2, ADDRESS3, 10);
        vm.stopPrank();

        assertEq(cleared, 3);
        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 0);
    }

    /**
     * @notice Single-item convention: resetting a non-existent approval reverts.
     */
    function test_ResetApprovalRevertsWhenNothingToClear() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(TransferApprovalNotFound.selector);
        ruleConditionalTransferLight.resetApproval(ADDRESS2, ADDRESS3, 10);
    }

    /**
     * @notice `resetApproval` is restricted to the transfer approver.
     */
    function test_ResetApprovalUnauthorizedReverts() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);

        vm.prank(ATTACKER);
        vm.expectRevert();
        ruleConditionalTransferLight.resetApproval(ADDRESS2, ADDRESS3, 10);

        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 1);
    }

    /*//////////////////////////////////////////////////////////////
            RuleConditionalTransferLightMultiToken.resetApproval
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The multi-token reset works on an UNBOUND token — `approveTransfer` requires the token
     *         to be bound, so without this the stranded approvals of F-4 would be unclearable.
     */
    function test_MultiTokenResetApprovalWorksOnUnboundToken() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLightMultiToken rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 1);

        rule.unbindToken(ADDRESS1);
        assertEq(rule.isTokenBound(ADDRESS1), false);

        // Re-approving is impossible once unbound...
        vm.expectRevert(RuleConditionalTransferLightMultiToken_InvalidToken.selector);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        // ...but cleanup still works, which is exactly what it is for.
        uint256 cleared = rule.resetApproval(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        vm.stopPrank();

        assertEq(cleared, 1);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 0);
    }

    /**
     * @notice Multi-token reset reverts when there is nothing to clear, and is approver-gated.
     */
    function test_MultiTokenResetApprovalGuards() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLightMultiToken rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);

        vm.expectRevert(RuleConditionalTransferLightMultiToken_TransferApprovalNotFound.selector);
        rule.resetApproval(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        vm.stopPrank();

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.resetApproval(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 1);
    }

    /*//////////////////////////////////////////////////////////////
              RuleMintAllowance.clearMintAllowances
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice BIND-1: an operator can discard stale quotas before rebinding, so they are NOT
     *         spendable through the newly bound token.
     */
    function test_ClearMintAllowancesPreventsStaleQuotaSurvivingRebind() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        rule.setMintAllowance(MINTER, 1000);
        rule.unbindToken(ADDRESS1);

        // Cleanup must work while NOTHING is bound.
        address[] memory minters = new address[](1);
        minters[0] = MINTER;
        rule.clearMintAllowances(minters);
        assertEq(rule.mintAllowance(MINTER), 0);

        rule.bindToken(ATTACKER);
        vm.stopPrank();

        // The new binder cannot spend the discarded quota.
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(RuleMintAllowance_AllowanceExceeded.selector, address(rule), MINTER, 0, 400)
        );
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 400);
    }

    /**
     * @notice Batch convention: clearing is idempotent and does not revert on already-zero minters.
     */
    function test_ClearMintAllowancesIsIdempotentBatch() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(ADDRESS1, 500);

        address[] memory minters = new address[](3);
        minters[0] = ADDRESS1; // has a quota
        minters[1] = ADDRESS2; // already zero
        minters[2] = ADDRESS1; // duplicate

        rule.clearMintAllowances(minters);
        rule.clearMintAllowances(minters); // twice — still no revert
        vm.stopPrank();

        assertEq(rule.mintAllowance(ADDRESS1), 0);
        assertEq(rule.mintAllowance(ADDRESS2), 0);
    }

    /**
     * @notice `clearMintAllowances` is restricted to the allowance operator.
     */
    function test_ClearMintAllowancesUnauthorizedReverts() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);
        vm.stopPrank();

        address[] memory minters = new address[](1);
        minters[0] = MINTER;

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.clearMintAllowances(minters);

        assertEq(rule.mintAllowance(MINTER), 1000);
    }
}
