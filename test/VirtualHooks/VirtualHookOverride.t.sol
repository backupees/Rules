// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {
    BlacklistQuarantineHarness,
    ConditionalTransferLightCustomExecutorHarness,
    ERC2980SelfWhitelistBlockHarness,
    IdentityRegistryPinnedHarness,
    MaxTotalSupplyCappedSetterHarness
} from "src/mocks/harness/VirtualHookOverrideHarnesses.sol";

/**
 * @title VirtualHookOverride
 * @notice Pins the `virtual` convention for functions that used to be non-`virtual`
 *         (`CLAUDE_ANALYSIS.md` E-1 internal hooks, E-2 `canTransfer`, E-3 public mutating functions).
 * @dev Two layers of protection. Compiling `VirtualHookOverrideHarnesses.sol` at all proves the
 *      functions are overridable -- removing `virtual` breaks the build. The assertions below prove
 *      the overrides are actually *reached*, which a compile-only check would not.
 *      E-3 coverage is representative rather than exhaustive; see the harness file for why.
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
     *         ERC-7943 twin the only one in `RuleNFTAdapter` (`CLAUDE_ANALYSIS.md` E-2).
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

    /*//////////////////////////////////////////////////////////////
              public mutating functions (E-3, representative)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice One override per family of the 27 public mutating functions made `virtual` by E-3.
     * @dev Sampled, not exhaustive: `virtual` is applied per function, so a regression on an
     *      uncovered sibling would still slip through. See the harness file's note.
     */
    function testSubclassCanOverrideTheApprovalAndTransferredEntrypoints() public {
        ConditionalTransferLightCustomExecutorHarness rule =
            new ConditionalTransferLightCustomExecutorHarness(DEFAULT_ADMIN_ADDRESS, SOLE_EXECUTOR);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS3);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        vm.stopPrank();
        assertEq(rule.approveTransferOverrideCalls(), 1);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 1, "base logic must still run");

        vm.prank(SOLE_EXECUTOR);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
        assertEq(rule.transferredOverrideCalls(), 1);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0, "base logic must still run");
    }

    function testSubclassCanOverrideAnAddressSetWrite() public {
        BlacklistQuarantineHarness rule =
            new BlacklistQuarantineHarness(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, QUARANTINED);

        vm.expectRevert(BlacklistQuarantineHarness.CannotListQuarantined.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(QUARANTINED);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        assertTrue(rule.isAddressListed(ADDRESS1), "base logic must still run");
    }

    function testSubclassCanOverrideARuleConfigurationSetter() public {
        TotalSupplyMock token = new TotalSupplyMock();
        MaxTotalSupplyCappedSetterHarness rule =
            new MaxTotalSupplyCappedSetterHarness(DEFAULT_ADMIN_ADDRESS, address(token), 100);

        vm.expectRevert(abi.encodeWithSelector(MaxTotalSupplyCappedSetterHarness.AboveHardCeiling.selector, 1_000_001));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(1_000_001);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(500);
        assertEq(rule.maxTotalSupply(), 500, "base logic must still run");
    }

    function testSubclassCanOverrideTheIdentityRegistrySetter() public {
        IdentityRegistryPinnedHarness rule =
            new IdentityRegistryPinnedHarness(DEFAULT_ADMIN_ADDRESS, ADDRESS3, false, false);

        vm.expectRevert(IdentityRegistryPinnedHarness.RegistryIsPinned.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setIdentityRegistry(ADDRESS1);

        assertEq(address(rule.identityRegistry()), ADDRESS3);
    }

    function testSubclassCanOverrideAnErc2980ListWrite() public {
        ERC2980SelfWhitelistBlockHarness rule =
            new ERC2980SelfWhitelistBlockHarness(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true);

        vm.expectRevert(ERC2980SelfWhitelistBlockHarness.CannotWhitelistTheRule.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(address(rule));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(ADDRESS1);
        assertTrue(rule.isWhitelisted(ADDRESS1), "base logic must still run");
    }
}
