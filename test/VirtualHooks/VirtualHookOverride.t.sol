// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {
    BlacklistQuarantineHarness,
    ConditionalTransferLightCustomExecutorHarness
} from "src/mocks/harness/VirtualHookOverrideHarnesses.sol";

/**
 * @title VirtualHookOverride
 * @notice Pins the `internal virtual` convention for hooks that used to be non-`virtual`
 *         (`FEEDBACK_12.md` E-1).
 * @dev Two layers of protection. Compiling `VirtualHookOverrideHarnesses.sol` at all proves the
 *      hooks are overridable -- removing `virtual` breaks the build. The assertions below prove the
 *      overrides are actually *reached*, which a compile-only check would not.
 */
contract VirtualHookOverride is Test, HelperContract {
    address private constant SOLE_EXECUTOR = address(0xE1);
    address private constant QUARANTINED = address(0xC0FFEE);

    /*//////////////////////////////////////////////////////////////
              _authorizeTransferExecution (operation rule)
    //////////////////////////////////////////////////////////////*/

    function testCustomExecutorPolicyReplacesTheBoundTokenCheck() public {
        ConditionalTransferLightCustomExecutorHarness rule =
            new ConditionalTransferLightCustomExecutorHarness(DEFAULT_ADMIN_ADDRESS, SOLE_EXECUTOR);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS3);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        vm.stopPrank();

        // The bound token would be authorized by the base policy; the override rejects it.
        vm.expectRevert(
            abi.encodeWithSelector(ConditionalTransferLightCustomExecutorHarness.NotTheSoleExecutor.selector, ADDRESS3)
        );
        vm.prank(ADDRESS3);
        rule.transferred(ADDRESS1, ADDRESS2, 10);

        // The custom executor is not the bound token, yet the override authorizes it.
        vm.prank(SOLE_EXECUTOR);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
    }

    /*//////////////////////////////////////////////////////////////
          _detectTransferRestriction / ...From (validation rule)
    //////////////////////////////////////////////////////////////*/

    function testSubclassCanExtendTheBlacklistRestrictionHooks() public {
        BlacklistQuarantineHarness rule =
            new BlacklistQuarantineHarness(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, QUARANTINED);
        uint8 quarantinedCode = rule.CODE_QUARANTINED();

        // The base rule still applies: an unlisted, unquarantined pair passes.
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);

        // The override adds its own rejection on both endpoints...
        assertEq(rule.detectTransferRestriction(QUARANTINED, ADDRESS2, 10), quarantinedCode);
        assertEq(rule.detectTransferRestriction(ADDRESS1, QUARANTINED, 10), quarantinedCode);

        // ...and on the spender, through the `From` hook.
        assertEq(rule.detectTransferRestrictionFrom(QUARANTINED, ADDRESS1, ADDRESS2, 10), quarantinedCode);
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10), TRANSFER_OK);

        // `super` still reaches the base implementation: a blacklisted sender keeps its own code.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_FROM_IS_BLACKLISTED);
    }

    /*//////////////////////////////////////////////////////////////
                    canTransfer (both overloads)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `canTransfer` was the only non-`virtual` view in `RuleTransferValidation`, and its
     *         ERC-7943 twin the only one in `RuleNFTAdapter` (`FEEDBACK_12.md` E-2).
     * @dev The harness makes both overloads return `false` unconditionally, contradicting
     *      `detectTransferRestriction`. If the override were not in effect the inherited
     *      implementation would delegate to the restriction hook and return `true` here, so this
     *      distinguishes a reached override from a silently ignored one.
     */
    function testSubclassCanOverrideBothCanTransferOverloads() public {
        BlacklistQuarantineHarness rule =
            new BlacklistQuarantineHarness(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, QUARANTINED);

        // The restriction hook still says the transfer is fine...
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 10), TRANSFER_OK);

        // ...but the overridden views answer for themselves.
        assertFalse(rule.canTransfer(ADDRESS1, ADDRESS2, 10));
        assertFalse(rule.canTransfer(ADDRESS1, ADDRESS2, 0, 10));

        // `canTransferFrom` was already `virtual` and is not overridden here, so it still tracks
        // the restriction hook -- confirming only the intended functions changed.
        assertTrue(rule.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10));
    }
}
